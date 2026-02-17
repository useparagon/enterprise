#!/bin/bash

# Script to assign roles to a service principal or user within an Azure subscription using `az cli`.
# This script documents the minimum required permissions to run the Azure infra and paragon Terraform workspaces.

# Define variables
SUBSCRIPTION_ID="your-azure-subscription-id"
PRINCIPAL_ID="your-service-principal-object-id-or-user-object-id"

# List of roles to assign at subscription level
# Note: Contributor role is sufficient for most operations, but we document specific roles
# for better security and compliance with least privilege principle.

ROLES=(
  # Contributor role - provides full access to manage all resources except grant access to others
  # This is the minimum role needed for Terraform to create and manage Azure resources
  "Contributor"
  # Needed to switch Key Vaults to RBAC and create role assignments
  "User Access Administrator"
)

# Alternative: If you want to use more granular permissions instead of Contributor,
# you would need the following roles (but Contributor is simpler and sufficient):
#
# GRANULAR_ROLES=(
#   "Network Contributor"              # For Virtual Networks, Subnets, NSGs, Private Endpoints
#   "DNS Zone Contributor"             # For Private DNS Zones
#   "PostgreSQL Flexible Server Contributor"  # For PostgreSQL Flexible Servers
#   "Redis Cache Contributor"          # For Redis Caches
#   "Storage Account Contributor"      # For Storage Accounts
#   "Kubernetes Cluster Contributor"   # For AKS Clusters
#   "Virtual Machine Contributor"      # For VM Scale Sets (bastion)
#   "Key Vault Contributor"            # For Key Vaults (management plane)
#   "Key Vault Administrator"          # For Key Vault data-plane access (RBAC)
#   "User Access Administrator"        # For role assignments (RBAC)
# )

# Assign Contributor role at subscription level
for ROLE in "${ROLES[@]}"; do
  echo "Assigning role '$ROLE' to principal $PRINCIPAL_ID..."
  az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "$ROLE" \
    --scope "/subscriptions/$SUBSCRIPTION_ID"
done

echo ""
echo "Role assignment complete!"
echo ""
echo "Note: The Contributor role provides the following permissions needed for Terraform:"
echo "  - Create and manage Resource Groups"
echo "  - Create and manage Virtual Networks, Subnets, and Network Security Groups"
echo "  - Create and manage Private DNS Zones and Private Endpoints"
echo "  - Create and manage PostgreSQL Flexible Servers"
echo "  - Create and manage Redis Caches"
echo "  - Create and manage Storage Accounts and Containers"
echo "  - Create and manage AKS Clusters and Node Pools"
echo "  - Create and manage Virtual Machine Scale Sets"
echo "  - Create and manage Key Vaults"
echo "  - Create and manage Key Vault role assignments (via User Access Administrator)"
echo "  - Create and manage Public IPs"
echo ""
echo "For Key Vault RBAC (permission model change + role assignments),"
echo "Terraform also needs User Access Administrator at subscription or resource group scope."
echo ""
echo "If you want the Terraform principal to manage Key Vault secrets/certs/keys,"
echo "assign Key Vault Administrator at the vault scope."
