#!/bin/bash

# This script is used to prepare the Terraform state for migration from the aws-on-prem workspace.
# It imports resources into the Terraform state and performs security group cleanup.
# Safe to run repeatedly: imports and cleanup are idempotent (skip if already in state / already done).
#
# If terraform apply fails with ResourceInUseException on EKS access entries, run this script with
# the failing entry ID as the first argument (e.g. ./migrate-state.sh 'paragon-enterprise-sinch:arn:aws:iam::024848480976:role/paragon-setup-role').
# The script loads AWS creds from vars.auto.tfvars and runs the import.
#
# IMPORTANT: This script must be run in this workspace directory where the resources are defined.
# The script will import resources into the current workspace's Terraform state. If you run it in the
# old workspace, the imports will fail because the resource addresses don't exist in that workspace's
# configuration.

# Helper function to extract value from terraform state
extract_state() {
    local resource_path="$1"
    local attribute="$2"
    local default_value="${3:-}"
    terraform state show "$resource_path" 2>/dev/null | grep -E "^\s+${attribute}\s+=" | awk '{print $3}' | tr -d '"' || echo "$default_value"
}

# Get script directory to locate vars.auto.tfvars
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS_FILE="${SCRIPT_DIR}/vars.auto.tfvars"

if [ ! -f "$VARS_FILE" ]; then
  echo "✗ ERROR: Could not find vars.auto.tfvars at ${VARS_FILE}"
  exit 1
fi

# Extract AWS credentials from vars.auto.tfvars
export AWS_ACCESS_KEY_ID=$(grep -E '^\s*aws_access_key_id\s*=' "$VARS_FILE" | awk -F'"' '{print $2}')
export AWS_SECRET_ACCESS_KEY=$(grep -E '^\s*aws_secret_access_key\s*=' "$VARS_FILE" | awk -F'"' '{print $2}')
REGION=$(grep -E '^\s*aws_region\s*=' "$VARS_FILE" | awk -F'"' '{print $2}')
SESSION_TOKEN=$(grep -E '^\s*aws_session_token\s*=' "$VARS_FILE" | awk -F'"' '{print $2}')
if [ -n "$SESSION_TOKEN" ]; then
  export AWS_SESSION_TOKEN="$SESSION_TOKEN"
elif [ -n "${AWS_SESSION_TOKEN:-}" ]; then
  export AWS_SESSION_TOKEN
fi
REGION="${REGION:-${AWS_REGION:-us-east-1}}"
export AWS_PAGER=""

# EKS access entry import: first arg is the failing entry ID (from the 409 error)
# e.g. ./migrate-state.sh 'paragon-enterprise-sinch:arn:aws:iam::024848480976:role/paragon-setup-role'
# If the resource is already in state but out of sync (409 + "already managing"), we remove it then re-import.
if [ -n "${1:-}" ] && [[ "$1" == *":arn:aws:iam::"* ]]; then
  IMPORT_ID="$1"
  CLUSTER_NAME="${IMPORT_ID%%:arn:*}"
  PRINCIPAL_ARN="${IMPORT_ID#*:}"
  case "$PRINCIPAL_ARN" in
    *:role/${CLUSTER_NAME}-bastion)   KEY="bastion" ;;
    *:role/${CLUSTER_NAME}-eks-admin) KEY="eks-admins" ;;
    *) KEY="$PRINCIPAL_ARN" ;;
  esac
  RESOURCE="module.cluster.module.eks.aws_eks_access_entry.this[\"${KEY}\"]"
  echo "Importing EKS access entry: ${KEY}"
  terraform state rm "${RESOURCE}" 2>/dev/null || true
  if terraform import "${RESOURCE}" "${IMPORT_ID}"; then
    echo "✓ Imported. Run terraform apply again."
  else
    echo "✗ Import failed."
    exit 1
  fi
  exit 0
fi

SG_ID_ARG="${1:-}"

# Security group cleanup section (non-fatal - will continue even if this fails)
echo "Attempting to clean up security group rules..."
SG_CLEANUP_SUCCESS=true

# Get security group ID from command line argument or extract from Terraform state
if [ -n "$SG_ID_ARG" ]; then
  SG_ID="$SG_ID_ARG"
  echo "Using provided security group ID: ${SG_ID}"
else
  echo "Extracting security group ID from Terraform state..."
  SG_ID=$(terraform state show 'module.cluster.module.eks.aws_security_group_rule.node["egress_all"]' 2>/dev/null | grep -E '^\s+security_group_id\s+=' | awk '{print $3}' | tr -d '"')
  
  if [ -z "$SG_ID" ]; then
    echo "⚠ WARNING: Could not determine security group ID from Terraform state (skipping security group cleanup)"
    SG_CLEANUP_SUCCESS=false
  fi
fi

if [ "$SG_CLEANUP_SUCCESS" = true ]; then
  # Query AWS directly for IPv4 (0.0.0.0/0) and IPv6 egress rules for this security group
  echo "Querying AWS for IPv4 (0.0.0.0/0) and IPv6 egress security group rules in ${SG_ID}..."

  RULE_IDS=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=${SG_ID}" \
    --query "SecurityGroupRules[?IsEgress == \`true\` && (CidrIpv6 != null || CidrIpv4 == \`0.0.0.0/0\`)].SecurityGroupRuleId" \
    --output text \
    --region "${REGION}" 2>/dev/null || true)

  if [ -z "$RULE_IDS" ]; then
    echo "⚠ WARNING: Could not find any matching security group rule IDs in AWS (skipping security group cleanup)"
    SG_CLEANUP_SUCCESS=false
  else
    echo "Found group-id: ${SG_ID}, security-group-rule-ids: ${RULE_IDS}"

    # Convert space-separated rule IDs to array and revoke all rules at once
    read -ra RULE_ID_ARRAY <<< "$RULE_IDS"

    if aws ec2 revoke-security-group-egress \
        --group-id "${SG_ID}" \
        --security-group-rule-ids "${RULE_ID_ARRAY[@]}" \
        --region "${REGION}" \
        --output json >/dev/null 2>&1; then
        echo "✓ Successfully deleted all rules from ${SG_ID}"
    else
        echo "⚠ WARNING: Failed to delete rules from AWS (they might have been deleted already or don't exist)"
        SG_CLEANUP_SUCCESS=false
    fi

    echo ""
    echo "Removing rule from Terraform state..."
    if terraform state rm 'module.cluster.module.eks.aws_security_group_rule.node["egress_all"]' 2>/dev/null; then
        echo "✓ Successfully removed from Terraform state"
    else
        echo "⚠ WARNING: Failed to remove from Terraform state (it might have been removed already)"
        SG_CLEANUP_SUCCESS=false
    fi
  fi
fi

if [ "$SG_CLEANUP_SUCCESS" = false ]; then
  echo "⚠ WARNING: Security group cleanup skipped or failed."
fi

echo ""
echo "Importing Kubernetes service account for EBS CSI controller..."
# Check if the service account already exists in state
SA_IMPORT_RESOURCE="module.cluster.kubernetes_service_account.ebs_csi_controller"
SA_IMPORT_ID="kube-system/ebs-csi-controller-sa"

if terraform state show "${SA_IMPORT_RESOURCE}" >/dev/null 2>&1; then
    echo "✓ Kubernetes service account already exists in Terraform state, skipping import"
else
    echo "  Importing: ${SA_IMPORT_RESOURCE} -> ${SA_IMPORT_ID}"
    
    # Always attempt the import - it might work, or we'll get a clear error message
    SA_IMPORT_OUTPUT=$(terraform import "${SA_IMPORT_RESOURCE}" "${SA_IMPORT_ID}" 2>&1)
    SA_IMPORT_EXIT_CODE=$?

    if [ $SA_IMPORT_EXIT_CODE -eq 0 ]; then
        # Verify it's actually in state now
        if terraform state show "${SA_IMPORT_RESOURCE}" >/dev/null 2>&1; then
            echo "✓ Successfully imported Kubernetes service account for EBS CSI controller"
        else
            echo "⚠ WARNING: Import appeared to succeed but resource not found in state"
            echo "  You may need to manually import:"
            echo "  terraform import '${SA_IMPORT_RESOURCE}' '${SA_IMPORT_ID}'"
        fi
    else
        # Import failed - check why
        if echo "$SA_IMPORT_OUTPUT" | grep -qE "couldn't find resource|reading IAM Role"; then
            echo "  ⚠ Import failed due to bastion validation (expected when bastion doesn't exist)"
            echo "  The service account exists in Kubernetes but couldn't be imported without bastion."
            echo ""
            echo "  IMPORTANT: You must import this manually after creating the bastion:"
            echo "    1. Create bastion: terraform apply -target=module.bastion (or use ./apply-bastion.sh)"
            echo "    2. Import service account: terraform import '${SA_IMPORT_RESOURCE}' '${SA_IMPORT_ID}'"
            echo ""
            echo "  If you don't import it, terraform apply will fail with:"
            echo "    'serviceaccounts \"ebs-csi-controller-sa\" already exists'"
        elif echo "$SA_IMPORT_OUTPUT" | grep -q "does not exist in the configuration"; then
            echo "  ⚠ WARNING: Failed to import - resource not found in configuration"
            echo "  NOTE: This error usually means you're not in the correct workspace directory."
            echo "  Make sure you're running this script in the NEW workspace where the resources"
            echo "  are defined in the Terraform configuration."
        else
            echo "  ⚠ WARNING: Failed to import Kubernetes service account (exit code: ${SA_IMPORT_EXIT_CODE})"
            echo "  Error output: ${SA_IMPORT_OUTPUT}"
            echo "  To fix this, manually run:"
            echo "  terraform import '${SA_IMPORT_RESOURCE}' '${SA_IMPORT_ID}'"
        fi
    fi
fi

echo ""
