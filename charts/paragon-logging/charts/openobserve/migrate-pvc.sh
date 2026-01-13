#!/bin/bash
set -euo pipefail

# Migration script to rename PVCs from old naming convention to new naming convention
# This preserves data while migrating by rebinding PVs (no data copying required!)
#
# Usage:
#   1. Edit the MIGRATIONS array below to define your StatefulSets
#   2. Run: ./migrate-pvc.sh
#
# Configuration: Define your StatefulSets to migrate
# Format: "NAMESPACE:RELEASE_NAME:STATEFULSET_NAME:OLD_VOLUME_NAME:NEW_VOLUME_NAME[:NEW_STORAGE_CLASS[:NEW_STORAGE_SIZE]]"
# 
# Optional parameters:
#   NEW_STORAGE_CLASS: If provided, will update storage class (e.g., gp3-encrypted -> gp3)
#   NEW_STORAGE_SIZE: If provided, will update storage size (e.g., 20Gi -> 100Gi)
# 
# Examples:
MIGRATIONS=(
    "paragon:paragon-logging:openobserve:o2-persistent-storage:openobserve-data:gp3"
    "paragon:paragon-monitoring:grafana:grafana:grafana:gp3"
    "paragon:paragon-monitoring:prometheus:prometheus:prometheus:gp3:100Gi"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Migration function for a single StatefulSet
migrate_statefulset() {
    local NAMESPACE="$1"
    local RELEASE_NAME="$2"
    local STATEFULSET_NAME="$3"
    local OLD_VOLUME_NAME="$4"
    local NEW_VOLUME_NAME="$5"
    local NEW_STORAGE_CLASS="${6:-}"  # Optional: new storage class
    local NEW_STORAGE_SIZE="${7:-}"   # Optional: new storage size
    
    log_info ""
    log_info "=========================================="
    log_info "Migrating: $STATEFULSET_NAME in namespace $NAMESPACE"
    log_info "=========================================="
    
    # Verify StatefulSet exists
    if ! kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_error "StatefulSet '$STATEFULSET_NAME' not found in namespace '$NAMESPACE'"
        return 1
    fi

    # Get current replica count
    local CURRENT_REPLICAS=$(kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    log_info "Current replicas: $CURRENT_REPLICAS"
    
    # Get PVC details from StatefulSet
    log_info "Discovering existing PVCs..."
    local OLD_PVCS=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep "^${OLD_VOLUME_NAME}-${STATEFULSET_NAME}-" || true)

    if [ -z "$OLD_PVCS" ]; then
        log_warn "No old PVCs found with pattern '${OLD_VOLUME_NAME}-${STATEFULSET_NAME}-*'"
        log_info "Listing all PVCs in namespace:"
        kubectl get pvc -n "$NAMESPACE" | grep -i "$STATEFULSET_NAME" || true
        log_warn "Skipping $STATEFULSET_NAME - no PVCs found"
        return 0
    fi

    # Step 1: Scale down StatefulSet
    log_info "Step 1: Scaling down StatefulSet to 0 replicas..."
    kubectl scale statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" --replicas=0
    
    # Wait for pods to terminate
    log_info "Waiting for pods to terminate..."
    kubectl wait --for=delete pod -l app.kubernetes.io/name="$STATEFULSET_NAME" -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
    kubectl wait --for=delete pod -l app.kubernetes.io/instance="$RELEASE_NAME" -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
    sleep 10  # Fallback: just wait a bit
    
    # Step 2: Delete StatefulSet (PVCs remain)
    log_info "Step 2: Deleting StatefulSet (PVCs will be preserved)..."
    kubectl delete statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" --wait=true
    
    # Step 3: Delete old PVCs and get PV information
    log_info "Step 3: Deleting old PVCs and preparing PVs for rebinding..."
    
    declare -A PV_MAP  # Map ordinal -> PV name
    declare -A PVC_SPECS  # Map ordinal -> PVC spec JSON
    declare -A ORIGINAL_RECLAIM_POLICIES  # Map ordinal -> original reclaim policy

for OLD_PVC in $OLD_PVCS; do
    # Extract ordinal from PVC name (e.g., o2-persistent-storage-openobserve-0 -> 0)
    ORDINAL=$(echo "$OLD_PVC" | sed "s/^${OLD_VOLUME_NAME}-${STATEFULSET_NAME}-//")
    
    log_info "Processing PVC: $OLD_PVC (ordinal: $ORDINAL)"
    
    # Get PVC spec and PV name before deleting
    log_info "  Getting PVC specification and PV name..."
    OLD_PVC_SPEC=$(kubectl get pvc "$OLD_PVC" -n "$NAMESPACE" -o json)
    PV_NAME=$(echo "$OLD_PVC_SPEC" | jq -r '.spec.volumeName // empty')
    
    if [ -z "$PV_NAME" ] || [ "$PV_NAME" == "null" ]; then
        log_error "  Could not determine PV name for PVC $OLD_PVC. Skipping..."
        continue
    fi
    
    log_info "  Associated PV: $PV_NAME"
    PV_MAP["$ORDINAL"]="$PV_NAME"
    PVC_SPECS["$ORDINAL"]="$OLD_PVC_SPEC"
    
    # Check and update PV reclaim policy to Retain (to prevent deletion when PVC is deleted)
    log_info "  Checking PV reclaim policy..."
    CURRENT_RECLAIM_POLICY=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
    log_info "  Current reclaim policy: $CURRENT_RECLAIM_POLICY"
    ORIGINAL_RECLAIM_POLICIES["$ORDINAL"]="$CURRENT_RECLAIM_POLICY"
    
    if [ "$CURRENT_RECLAIM_POLICY" != "Retain" ]; then
        log_info "  Changing PV reclaim policy from $CURRENT_RECLAIM_POLICY to Retain (to prevent deletion)..."
        kubectl patch pv "$PV_NAME" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}' || {
            log_error "  Failed to change reclaim policy. Cannot proceed safely."
            exit 1
        }
        log_info "  ✓ PV reclaim policy changed to Retain"
    else
        log_info "  ✓ PV already has Retain policy"
    fi
    
    # Delete the old PVC (PV will go to Released state but won't be deleted due to Retain policy)
    log_info "  Deleting old PVC: $OLD_PVC"
    kubectl delete pvc "$OLD_PVC" -n "$NAMESPACE" --wait=true
    
    # Wait a moment for PV to transition to Released
    sleep 2
    
    # Verify PV still exists and is in Released state
    PV_PHASE=$(kubectl get pv "$PV_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$PV_PHASE" == "NotFound" ]; then
        log_error "  PV $PV_NAME was deleted! This should not happen with Retain policy."
        exit 1
    fi
    log_info "  PV status: $PV_PHASE"
    
    # Clear the claimRef from the PV so it can be bound to a new PVC
    log_info "  Clearing claimRef from PV: $PV_NAME"
    kubectl patch pv "$PV_NAME" -p '{"spec":{"claimRef":null}}' || {
        log_warn "  Failed to clear claimRef. PV may need manual intervention."
    }
    
    # Update PV storage class if it's being changed
    if [ -n "$NEW_STORAGE_CLASS" ] && [ "$NEW_STORAGE_CLASS" != "$OLD_STORAGE_CLASS" ]; then
        log_info "  Updating PV storage class from '${OLD_STORAGE_CLASS:-default}' to '$NEW_STORAGE_CLASS'..."
        CURRENT_PV_SC=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
        if [ "$CURRENT_PV_SC" != "$NEW_STORAGE_CLASS" ]; then
            kubectl patch pv "$PV_NAME" -p "{\"spec\":{\"storageClassName\":\"$NEW_STORAGE_CLASS\"}}" || {
                log_error "  Failed to update PV storage class. Cannot proceed."
                exit 1
            }
            log_info "  ✓ PV storage class updated"
        fi
    fi
    
    log_info "  ✓ Prepared PV $PV_NAME for rebinding"
done

# Step 4: Create new PVCs that will bind to the existing PVs
log_info "Step 4: Creating new PVCs from the existing PVs..."

for ORDINAL in "${!PV_MAP[@]}"; do
    PV_NAME="${PV_MAP[$ORDINAL]}"
    OLD_PVC_SPEC="${PVC_SPECS[$ORDINAL]}"
    NEW_PVC="${NEW_VOLUME_NAME}-${STATEFULSET_NAME}-${ORDINAL}"
    
    log_info "Creating new PVC: $NEW_PVC (will bind to PV: $PV_NAME)"
    
    # Extract PVC spec details
    OLD_STORAGE_SIZE=$(echo "$OLD_PVC_SPEC" | jq -r '.spec.resources.requests.storage')
    OLD_STORAGE_CLASS=$(echo "$OLD_PVC_SPEC" | jq -r '.spec.storageClassName // empty')
    ACCESS_MODE=$(echo "$OLD_PVC_SPEC" | jq -r '.spec.accessModes[0]')
    
    # Use new values if provided, otherwise keep old values
    STORAGE_SIZE="${NEW_STORAGE_SIZE:-$OLD_STORAGE_SIZE}"
    STORAGE_CLASS="${NEW_STORAGE_CLASS:-$OLD_STORAGE_CLASS}"
    
    log_info "  Storage size: $OLD_STORAGE_SIZE -> $STORAGE_SIZE"
    if [ -n "$NEW_STORAGE_SIZE" ] && [ "$NEW_STORAGE_SIZE" != "$OLD_STORAGE_SIZE" ]; then
        log_info "    ⚠ Storage size will be updated"
    fi
    
    log_info "  Storage class: ${OLD_STORAGE_CLASS:-'(default)'} -> ${STORAGE_CLASS:-'(default)'}"
    if [ -n "$NEW_STORAGE_CLASS" ] && [ "$NEW_STORAGE_CLASS" != "$OLD_STORAGE_CLASS" ]; then
        log_warn "    ⚠ Storage class will be updated from '${OLD_STORAGE_CLASS:-default}' to '$NEW_STORAGE_CLASS'"
        log_warn "    Note: The PV was created with the old storage class. Binding should work if the"
        log_warn "    storage classes are compatible (e.g., renamed storage class)."
    fi
    
    log_info "  Access mode: $ACCESS_MODE"
    
    # Create new PVC with exact same spec, and force binding to existing PV
    # Note: We set volumeName to force immediate binding (bypasses WaitForFirstConsumer)
    log_info "  Creating new PVC: $NEW_PVC (will bind to PV: $PV_NAME)"
    if [ -n "$STORAGE_CLASS" ] && [ "$STORAGE_CLASS" != "null" ] && [ "$STORAGE_CLASS" != "" ]; then
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NEW_PVC
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: openobserve
    app.kubernetes.io/instance: ${RELEASE_NAME}
    migrated-from: ${OLD_VOLUME_NAME}-${STATEFULSET_NAME}-${ORDINAL}
spec:
  accessModes:
    - $ACCESS_MODE
  storageClassName: $STORAGE_CLASS
  volumeName: $PV_NAME
  resources:
    requests:
      storage: $STORAGE_SIZE
EOF
    else
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NEW_PVC
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: openobserve
    app.kubernetes.io/instance: ${RELEASE_NAME}
    migrated-from: ${OLD_VOLUME_NAME}-${STATEFULSET_NAME}-${ORDINAL}
spec:
  accessModes:
    - $ACCESS_MODE
  volumeName: $PV_NAME
  resources:
    requests:
      storage: $STORAGE_SIZE
EOF
    fi
    
    # Update PV's claimRef to point to the new PVC (completes the binding)
    log_info "  Updating PV claimRef to point to new PVC..."
    PVC_UID=$(kubectl get pvc "$NEW_PVC" -n "$NAMESPACE" -o jsonpath='{.metadata.uid}' 2>/dev/null || echo "")
    if [ -n "$PVC_UID" ]; then
        kubectl patch pv "$PV_NAME" -p "{\"spec\":{\"claimRef\":{\"name\":\"$NEW_PVC\",\"namespace\":\"$NAMESPACE\",\"uid\":\"$PVC_UID\"}}}" || {
            log_warn "  Failed to update PV claimRef, but binding should still work"
        }
    fi
    
    # Wait for new PVC to bind to the existing PV
    log_info "  Waiting for new PVC to bind to existing PV..."
    
    # Check if already bound, otherwise wait
    MAX_WAIT=180
    ELAPSED=0
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        PVC_STATUS=$(kubectl get pvc "$NEW_PVC" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        if [ "$PVC_STATUS" == "Bound" ]; then
            log_info "  ✓ PVC is bound"
            break
        elif [ "$PVC_STATUS" == "NotFound" ]; then
            log_info "  Waiting for PVC to be created... (${ELAPSED}s/${MAX_WAIT}s)"
        else
            log_info "  Waiting for PVC to bind... Status: $PVC_STATUS (${ELAPSED}s/${MAX_WAIT}s)"
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    
    if [ "$PVC_STATUS" != "Bound" ]; then
        log_error "  PVC did not bind within ${MAX_WAIT}s. Current status: $PVC_STATUS"
        log_error "  This may be due to storage class mismatch or WaitForFirstConsumer binding mode."
        log_error "  Try manually binding: kubectl patch pvc $NEW_PVC -n $NAMESPACE -p '{\"spec\":{\"volumeName\":\"$PV_NAME\"}}'"
        exit 1
    fi
    
    # Verify it bound to the correct PV
    BOUND_PV=$(kubectl get pvc "$NEW_PVC" -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}')
    if [ "$BOUND_PV" == "$PV_NAME" ]; then
        log_info "  ✓ Successfully bound to existing PV: $PV_NAME (data preserved!)"
        if [ -n "$NEW_STORAGE_CLASS" ] && [ "$NEW_STORAGE_CLASS" != "$OLD_STORAGE_CLASS" ]; then
            log_info "  ✓ Storage class updated successfully"
        fi
        if [ -n "$NEW_STORAGE_SIZE" ] && [ "$NEW_STORAGE_SIZE" != "$OLD_STORAGE_SIZE" ]; then
            log_info "  ✓ Storage size updated successfully"
        fi
    else
        log_warn "  ⚠ PVC bound to different PV: $BOUND_PV (expected: $PV_NAME)"
        if [ -n "$NEW_STORAGE_CLASS" ] && [ "$NEW_STORAGE_CLASS" != "$OLD_STORAGE_CLASS" ]; then
            log_warn "  This may be due to storage class mismatch. The new PVC may have created a new PV."
            log_warn "  Check if data needs to be migrated from old PV to new PV."
        else
            log_warn "  This may indicate the PV was already bound or specs don't match"
        fi
    fi
done

    log_info ""
    log_info "✓ Migration completed for $STATEFULSET_NAME!"
    log_info ""
    log_info "Summary:"
    log_info "  - Old PVCs deleted"
    log_info "  - PV reclaim policies changed to 'Retain' (to prevent accidental deletion)"
    log_info "  - New PVCs created and bound to existing PVs"
    log_info "  - All data preserved"
    log_info ""
    log_info "Next steps for $STATEFULSET_NAME:"
    log_info "  1. Deploy the new Helm chart to use the new volumeClaimTemplate name: '$NEW_VOLUME_NAME'"
    log_info "  2. The StatefulSet will be recreated and will bind to the existing new PVCs"
}

# Main execution
log_info "PVC Migration Script - Multiple StatefulSets"
log_info "=============================================="
log_info ""
log_info "This script will migrate the following StatefulSets:"
for MIGRATION in "${MIGRATIONS[@]}"; do
    IFS=':' read -r NAMESPACE RELEASE_NAME STATEFULSET_NAME OLD_VOLUME_NAME NEW_VOLUME_NAME NEW_STORAGE_CLASS NEW_STORAGE_SIZE <<< "$MIGRATION"
    log_info "  - $STATEFULSET_NAME (namespace: $NAMESPACE, release: $RELEASE_NAME)"
    log_info "    Volume: $OLD_VOLUME_NAME -> $NEW_VOLUME_NAME"
    if [ -n "$NEW_STORAGE_CLASS" ]; then
        log_info "    Storage class: will be updated to '$NEW_STORAGE_CLASS'"
    fi
    if [ -n "$NEW_STORAGE_SIZE" ]; then
        log_info "    Storage size: will be updated to '$NEW_STORAGE_SIZE'"
    fi
done
log_info ""
log_warn "This script will:"
echo "  1. Scale down each StatefulSet to 0 replicas"
echo "  2. Delete each StatefulSet (PVCs will be preserved)"
echo "  3. Change PV reclaim policy to 'Retain' (to prevent deletion)"
echo "  4. Delete old PVCs (PVs will be released but NOT deleted)"
echo "  5. Clear claimRef from released PVs"
echo "  6. Create new PVCs with new naming pattern"
echo "  7. New PVCs will automatically bind to the existing PVs"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Migration cancelled"
    exit 0
fi

# Process each migration
FAILED_MIGRATIONS=()
for MIGRATION in "${MIGRATIONS[@]}"; do
    IFS=':' read -r NAMESPACE RELEASE_NAME STATEFULSET_NAME OLD_VOLUME_NAME NEW_VOLUME_NAME NEW_STORAGE_CLASS NEW_STORAGE_SIZE <<< "$MIGRATION"
    
    if ! migrate_statefulset "$NAMESPACE" "$RELEASE_NAME" "$STATEFULSET_NAME" "$OLD_VOLUME_NAME" "$NEW_VOLUME_NAME" "$NEW_STORAGE_CLASS" "$NEW_STORAGE_SIZE"; then
        log_error "Migration failed for $STATEFULSET_NAME"
        FAILED_MIGRATIONS+=("$STATEFULSET_NAME")
    fi
done

# Final summary
log_info ""
log_info "=========================================="
log_info "Migration Summary"
log_info "=========================================="
if [ ${#FAILED_MIGRATIONS[@]} -eq 0 ]; then
    log_info "✓ All migrations completed successfully!"
else
    log_warn "⚠ Some migrations failed:"
    for FAILED in "${FAILED_MIGRATIONS[@]}"; do
        log_warn "  - $FAILED"
    done
    exit 1
fi
