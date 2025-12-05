#!/bin/bash

# This script is used to prepare the Terraform state for migration from the aws-on-prem workspace.
# It imports resources into the Terraform state and performs security group cleanup.
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

# Session token is optional - check if it exists in the file or environment
SESSION_TOKEN=$(grep -E '^\s*aws_session_token\s*=' "$VARS_FILE" | awk -F'"' '{print $2}')
if [ -n "$SESSION_TOKEN" ]; then
  export AWS_SESSION_TOKEN="$SESSION_TOKEN"
elif [ -n "$AWS_SESSION_TOKEN" ]; then
  # Use existing environment variable if set
  export AWS_SESSION_TOKEN
fi

# Use environment variable if REGION wasn't found in file
REGION="${REGION:-${AWS_REGION:-us-east-1}}"

export AWS_PAGER=""

# Security group cleanup section (non-fatal - will continue even if this fails)
echo "Attempting to clean up security group rules..."
SG_CLEANUP_SUCCESS=true

# Get security group ID from command line argument or extract from Terraform state
if [ -n "$1" ]; then
  SG_ID="$1"
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
  echo "⚠ WARNING: Security group cleanup skipped or failed, continuing with EKS access entry import..."
fi

echo ""
echo "Extracting caller ARN and cluster name for EKS access entry import..."
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text --region "${REGION}" 2>/dev/null || echo "")

if [ -z "$CALLER_ARN" ]; then
  echo "✗ ERROR: Could not determine caller ARN from AWS STS."
  exit 1
fi

# Get cluster name from Terraform state
CLUSTER_NAME=$(terraform state show 'module.cluster.module.eks.aws_eks_cluster.this[0]' 2>/dev/null | grep -E '^\s+name\s+=' | awk '{print $3}' | tr -d '"')

if [ -z "$CLUSTER_NAME" ]; then
  # Fallback: try to get from organization in vars.auto.tfvars
  ORGANIZATION=$(grep -E '^\s*organization\s*=' "$VARS_FILE" | awk -F'"' '{print $2}')
  if [ -n "$ORGANIZATION" ]; then
    CLUSTER_NAME="paragon-enterprise-${ORGANIZATION}"
    echo "✓ Using cluster name from organization: ${CLUSTER_NAME}"
  else
    echo "✗ ERROR: Could not determine cluster name from Terraform state or vars.auto.tfvars."
    # exit 1
  fi
fi

echo "✓ Found caller-arn: ${CALLER_ARN}, cluster-name: ${CLUSTER_NAME}"

if [ -n "$CALLER_ARN" ] && [ -n "$CLUSTER_NAME" ]; then
    echo ""
    echo "Importing EKS access entry into Terraform state..."
    # Check if the access entry already exists in state
    IMPORT_RESOURCE="module.cluster.module.eks.aws_eks_access_entry.this[\"${CALLER_ARN}\"]"
    IMPORT_ID="${CLUSTER_NAME}:${CALLER_ARN}"

    if terraform state show "${IMPORT_RESOURCE}" >/dev/null 2>&1; then
        echo "✓ EKS access entry already exists in Terraform state, skipping import"
    else
        echo "  Importing: ${IMPORT_RESOURCE} -> ${IMPORT_ID}"
        IMPORT_OUTPUT=$(terraform import "${IMPORT_RESOURCE}" "${IMPORT_ID}" 2>&1)
        IMPORT_EXIT_CODE=$?
        
        if [ $IMPORT_EXIT_CODE -eq 0 ]; then
            echo "✓ Successfully imported EKS access entry for ${CALLER_ARN}"
        else
            # Check if the error indicates the resource already exists in AWS
            # This is actually fine - we just need to get it into Terraform state
            if echo "$IMPORT_OUTPUT" | grep -qE "ResourceInUseException|already in use|already exists|Error importing"; then
                echo "⚠ WARNING: Import failed, but this may be expected if the resource exists in AWS"
                echo "  Error: ${IMPORT_OUTPUT}"
                echo ""
                echo "  If you see a 'ResourceInUseException' or 'already in use' error when applying,"
                echo "  you may need to manually import the resource:"
                echo "  terraform import '${IMPORT_RESOURCE}' '${IMPORT_ID}'"
            else
                echo "⚠ WARNING: Failed to import EKS access entry (exit code: ${IMPORT_EXIT_CODE})"
                echo "  Error output: ${IMPORT_OUTPUT}"
                echo ""
                if echo "$IMPORT_OUTPUT" | grep -q "does not exist in the configuration"; then
                    echo "  NOTE: This error usually means you're not in the correct workspace directory."
                    echo "  Make sure you're running this script in the NEW workspace where the resources"
                    echo "  are defined in the Terraform configuration."
                    echo ""
                fi
                echo "  To fix this, manually run:"
                echo "  terraform import '${IMPORT_RESOURCE}' '${IMPORT_ID}'"
            fi
        fi
    fi
else
    echo ""
    echo "⚠ WARNING: Skipping EKS access entry import (missing caller ARN or cluster name)"
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
    SA_IMPORT_OUTPUT=$(terraform import "${SA_IMPORT_RESOURCE}" "${SA_IMPORT_ID}" 2>&1)
    SA_IMPORT_EXIT_CODE=$?
    
    if [ $SA_IMPORT_EXIT_CODE -eq 0 ]; then
        echo "✓ Successfully imported Kubernetes service account for EBS CSI controller"
    else
        # Check if the error indicates the resource already exists
        if echo "$SA_IMPORT_OUTPUT" | grep -qE "ResourceInUseException|already in use|already exists|Error importing"; then
            echo "⚠ WARNING: Import failed, but this may be expected if the resource exists"
            echo "  Error: ${SA_IMPORT_OUTPUT}"
            echo ""
            echo "  If you see a conflict error when applying,"
            echo "  you may need to manually import the resource:"
            echo "  terraform import '${SA_IMPORT_RESOURCE}' '${SA_IMPORT_ID}'"
        else
            echo "⚠ WARNING: Failed to import Kubernetes service account (exit code: ${SA_IMPORT_EXIT_CODE})"
            echo "  Error output: ${SA_IMPORT_OUTPUT}"
            echo ""
            if echo "$SA_IMPORT_OUTPUT" | grep -q "does not exist in the configuration"; then
                echo "  NOTE: This error usually means you're not in the correct workspace directory."
                echo "  Make sure you're running this script in the NEW workspace where the resources"
                echo "  are defined in the Terraform configuration."
                echo ""
            fi
            echo "  To fix this, manually run:"
            echo "  terraform import '${SA_IMPORT_RESOURCE}' '${SA_IMPORT_ID}'"
        fi
    fi
fi

echo ""
