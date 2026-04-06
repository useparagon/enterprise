# ---------------------------------------------------------------------------
# AWS credentials
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key for AWS account to provision resources on."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for AWS account to provision resources on."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_session_token" {
  description = "AWS session token."
  type        = string
  sensitive   = true
  default     = null
}

# ---------------------------------------------------------------------------
# Account
# ---------------------------------------------------------------------------

variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "az_count" {
  description = "Number of AZs to cover in a given region."
  type        = number
  default     = 2
  nullable    = false
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets."
  type        = number
  default     = 3
  nullable    = false
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "rds_instance_class" {
  description = "The RDS instance class type used for Postgres."
  type        = string
  default     = "db.t4g.small"
  nullable    = false
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
  default     = "16"
  nullable    = false
}

variable "rds_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

variable "rds_multi_az" {
  description = "Whether or not to enable multi-AZ in each RDS instance."
  type        = bool
  default     = true
  nullable    = false
}

variable "rds_restore_from_snapshot" {
  description = "Specifies that RDS instances should be restored from a snapshot."
  type        = bool
  default     = false
  nullable    = false
}

variable "rds_final_snapshot_enabled" {
  description = "Specifies that RDS instances should perform a final snapshot before being deleted."
  type        = bool
  default     = true
  nullable    = false
}

# ---------------------------------------------------------------------------
# ElastiCache
# ---------------------------------------------------------------------------

variable "elasticache_node_type" {
  description = "The ElastiCache node type used for Redis."
  type        = string
  default     = "cache.r6g.large"
  nullable    = false
}

variable "elasticache_multiple_instances" {
  description = "Whether or not to create multiple ElastiCache instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

variable "elasticache_multi_az" {
  description = "Whether or not to enable multi-AZ in each ElastiCache instance."
  type        = bool
  default     = true
  nullable    = false
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.34"
  nullable    = false
}

variable "eks_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes nodes."
  type        = string
  default     = "m6a.xlarge"
  nullable    = false
}

variable "eks_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "t3a.xlarge,t3.xlarge,m5a.xlarge,m5.xlarge,m6a.xlarge,m6i.xlarge,m7a.xlarge,m7i.xlarge,r5a.xlarge,m4.xlarge"
  nullable    = false
}

variable "eks_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 75
  nullable    = false
  validation {
    condition     = var.eks_spot_instance_percent >= 0 && var.eks_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "eks_min_node_count" {
  description = "The minimum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 2
  nullable    = false
}

variable "eks_max_node_count" {
  description = "The maximum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 40
  nullable    = false
}

variable "eks_admin_arns" {
  description = "Array of ARNs for IAM users or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "create_autoscaling_linked_role" {
  description = "Whether or not to create an IAM role for autoscaling."
  type        = bool
  default     = true
  nullable    = false
}

# ---------------------------------------------------------------------------
# MSK (Kafka)
# ---------------------------------------------------------------------------

variable "msk_kafka_version" {
  description = "The Kafka version for the MSK cluster."
  type        = string
  // NOTE: to use a small instance type like `kafka.t3.small`, we need to use an older version that uses zookeeper
  // we're default to an older version to keep costs low, but we can override this if we use a supported larger instance type
  default  = "3.6.0"
  nullable = false
}

variable "msk_kafka_num_broker_nodes" {
  description = "The number of broker nodes for the MSK cluster."
  type        = number
  default     = 2
  nullable    = false
}

variable "msk_autoscaling_enabled" {
  description = "Whether to enable autoscaling for the MSK cluster."
  type        = bool
  default     = true
  nullable    = false
}

variable "msk_instance_type" {
  description = "The instance type for the MSK cluster."
  type        = string
  default     = "kafka.t3.small"
  nullable    = false
}

# ---------------------------------------------------------------------------
# Security & storage
# ---------------------------------------------------------------------------

variable "master_guardduty_account_id" {
  description = "Optional AWS account id to delegate GuardDuty control to."
  type        = string
  default     = null
}

variable "mfa_enabled" {
  description = "Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion)"
  type        = bool
  default     = false
  nullable    = false
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = string
  default     = ""
  nullable    = false
}

variable "disable_cloudtrail" {
  description = "Used to specify that Cloudtrail is disabled."
  type        = bool
  default     = true
  nullable    = false
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
  default     = false
  nullable    = false
}

variable "app_bucket_expiration" {
  description = "The number of days to retain S3 app data before deleting"
  type        = number
  default     = 90
  nullable    = false
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
  default     = 365
  nullable    = false
}

variable "auditlogs_lock_enabled" {
  description = "Whether to enable S3 Object Lock for the audit logs bucket."
  type        = bool
  default     = false
  nullable    = false
}

# ---------------------------------------------------------------------------
# Cloudflare
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS`"
  type        = string
  sensitive   = true
  default     = "dummy-cloudflare-tokens-must-be-40-chars"
  nullable    = false
}

variable "cloudflare_tunnel_enabled" {
  description = "Flag whether to enable Cloudflare Zero Trust tunnel for bastion"
  type        = bool
  default     = false
  nullable    = false
}

variable "cloudflare_tunnel_subdomain" {
  description = "Subdomain under the Cloudflare Zone to create the tunnel"
  type        = string
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_zone_id" {
  description = "Zone ID for Cloudflare domain"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_email_domain" {
  description = "Email domain for Cloudflare access"
  type        = string
  sensitive   = true
  default     = "useparagon.com"
  nullable    = false
}

# ---------------------------------------------------------------------------
# Feature flags
# ---------------------------------------------------------------------------

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
  default     = false
  nullable    = false
}

variable "argocd_enabled" {
  description = "Enable ArgoCD-based GitOps deployment. When true, bootstraps ArgoCD and ESO on the cluster, writes config to Secrets Manager, and applies ArgoCD Application manifests."
  type        = bool
  default     = false
  nullable    = false
}

# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

variable "migrated_workspace" {
  description = "Override the workspace name to preserve naming conventions when migrating from legacy workspaces"
  type        = string
  default     = null
}

variable "migrated_passwords" {
  description = "Override credentials to preserve complexity conventions when migrating from legacy workspaces"
  type        = map(string)
  default     = {}
  nullable    = false
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — tooling
# ---------------------------------------------------------------------------

variable "argocd_version" {
  description = "ArgoCD release version (e.g. v2.14.11). Used to fetch the install manifest from GitHub."
  type        = string
  default     = "v2.14.11"
  nullable    = false
}

variable "eso_chart_version" {
  description = "Helm chart version for external-secrets operator."
  type        = string
  default     = "0.14.4"
  nullable    = false
}

variable "argocd_auto_sync" {
  description = "Whether ArgoCD Applications should auto-sync on git/chart changes."
  type        = bool
  default     = true
  nullable    = false
}

variable "argocd_self_heal" {
  description = "Whether ArgoCD should auto-correct drift from desired state."
  type        = bool
  default     = true
  nullable    = false
}

variable "argocd_slack_token" {
  description = "Optional Slack bot token for ArgoCD sync notifications."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_slack_channel" {
  description = "Slack channel name for ArgoCD notifications."
  type        = string
  default     = ""
  nullable    = false
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — Paragon application charts
# ---------------------------------------------------------------------------

variable "argocd_app_chart_repository" {
  description = "Helm chart repository URL for Paragon application charts (e.g. OCI registry or HTTPS repo)."
  type        = string
  default     = ""
  nullable    = false
}

variable "paragon_chart_version" {
  description = "Target chart version or constraint for Paragon charts deployed via ArgoCD (e.g. '2026.04.*'). Required when argocd_enabled is true."
  type        = string
  default     = null
}

variable "paragon_monitors_enabled" {
  description = "Whether monitoring charts should be deployed via ArgoCD."
  type        = bool
  default     = false
  nullable    = false
}

variable "paragon_monitor_version" {
  description = "Chart version for the monitoring stack when deployed via ArgoCD. Defaults to paragon_chart_version when paragon_monitors_enabled is true."
  type        = string
  default     = null
}

variable "paragon_managed_sync_config" {
  description = "Optional managed-sync secret data to write to Secrets Manager. Null when managed sync is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "paragon_managed_sync_version" {
  description = "Chart version for managed-sync when deployed via ArgoCD. Required when argocd_enabled and managed_sync_enabled are both true."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — application secrets
# ---------------------------------------------------------------------------

variable "argocd_env_config" {
  description = "Pre-merged map of environment variables to store in Secrets Manager for the Paragon application. When null, secrets are not written (use for phased migration)."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "argocd_docker_registry_server" {
  description = "Docker registry server for ArgoCD image pulls."
  type        = string
  default     = "docker.io"
  nullable    = false
}

variable "argocd_docker_username" {
  description = "Docker username for ArgoCD image pulls."
  type        = string
  default     = null
}

variable "argocd_docker_password" {
  description = "Docker password for ArgoCD image pulls."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_docker_email" {
  description = "Docker email for ArgoCD image pulls."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — ingress
# ---------------------------------------------------------------------------

variable "argocd_ingress_scheme" {
  description = "ALB scheme for ArgoCD-managed ingress: internet-facing or internal."
  type        = string
  default     = "internet-facing"
  nullable    = false
}

variable "argocd_certificate_arn" {
  description = "ACM certificate ARN for the ArgoCD-managed ingress."
  type        = string
  default     = ""
  nullable    = false
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  hash        = substr(sha256(data.aws_caller_identity.current.account_id), 0, 8)
  environment = "enterprise"
  workspace   = coalesce(var.migrated_workspace, "paragon-${var.organization}-${local.hash}")

  default_tags = merge(
    {
      Name        = "paragon-${var.organization}"
      Environment = local.environment
      Creator     = "Terraform"
    },
    trimspace(var.organization) == "" ? {} : { Organization = var.organization }
  )

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])

  eks_ondemand_node_instance_type = distinct([for value in split(",", var.eks_ondemand_node_instance_type) : trimspace(value)])
  eks_spot_node_instance_type     = distinct([for value in split(",", var.eks_spot_node_instance_type) : trimspace(value)])

  # ArgoCD: guard for secrets module — only activate when Docker creds and env config are provided
  argocd_secrets_ready = (
    var.argocd_env_config != null &&
    var.argocd_docker_username != null &&
    var.argocd_docker_password != null
  )

  argocd_openobserve_credentials = var.argocd_enabled ? {
    email    = "${random_string.openobserve_email[0].result}@useparagon.com"
    password = random_password.openobserve_password[0].result
  } : null

  # Resolved chart versions — only meaningful when argocd_enabled = true
  paragon_chart_version        = var.paragon_chart_version
  paragon_monitor_version      = var.paragon_monitor_version != null ? var.paragon_monitor_version : var.paragon_chart_version
  paragon_managed_sync_version = var.paragon_managed_sync_version
}

resource "terraform_data" "validate_argocd_versions" {
  count = var.argocd_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.paragon_chart_version != null
      error_message = "paragon_chart_version is required when argocd_enabled is true."
    }
    precondition {
      condition     = !var.managed_sync_enabled || var.paragon_managed_sync_version != null
      error_message = "paragon_managed_sync_version is required when argocd_enabled and managed_sync_enabled are both true."
    }
  }
}

# ---------------------------------------------------------------------------
# Generated resources (conditional on argocd_enabled)
# ---------------------------------------------------------------------------

resource "random_string" "openobserve_email" {
  count = var.argocd_enabled ? 1 : 0

  length  = 12
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_password" "openobserve_password" {
  count = var.argocd_enabled ? 1 : 0

  length  = 32
  lower   = true
  numeric = true
  special = false
  upper   = true
}
