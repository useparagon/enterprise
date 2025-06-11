# credentials
variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key for AWS account to provision resources on."
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for AWS account to provision resources on."
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "AWS session token."
  type        = string
  sensitive   = true
  default     = null
}

# account
variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string
}

# network
variable "az_count" {
  description = "Number of AZs to cover in a given region."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets."
  type        = number
  default     = 3
}

# rds
variable "rds_instance_class" {
  description = "The RDS instance class type used for Postgres."
  type        = string
  default     = "db.t4g.small"
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
  default     = "14"
}

variable "rds_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Whether or not to enable multi-AZ in each RDS instance."
  type        = bool
  default     = true
}

variable "rds_restore_from_snapshot" {
  description = "Specifies that RDS instances should be restored from a snapshot."
  type        = bool
  default     = false
}

variable "rds_final_snapshot_enabled" {
  description = "Specifies that RDS instances should perform a final snapshot before being deleted."
  type        = bool
  default     = true
}

# elasticache
variable "elasticache_node_type" {
  description = "The ElastiCache node type used for Redis."
  type        = string
  default     = "cache.r6g.large"
}

variable "elasticache_multiple_instances" {
  description = "Whether or not to create multiple ElastiCache instances. Used for higher volume installations."
  type        = bool
  default     = true
}

variable "elasticache_multi_az" {
  description = "Whether or not to enable multi-AZ in each ElastiCache instance."
  type        = bool
  default     = true
}

# eks
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.31"
}

variable "eks_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes nodes."
  type        = string
  default     = "t3a.large,t3.large"
}

variable "eks_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "t3a.large,t3.large"
}

variable "eks_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 75
  validation {
    condition     = var.eks_spot_instance_percent >= 0 && var.eks_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "eks_min_node_count" {
  description = "The minimum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 4
}

variable "eks_max_node_count" {
  description = "The maximum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 30
}

variable "eks_admin_arns" {
  description = "Array of ARNs for IAM users or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard."
  type        = list(string)
  default     = []
}

# security
variable "master_guardduty_account_id" {
  description = "Optional AWS account id to delegate GuardDuty control to."
  type        = string
  default     = null
}

variable "mfa_enabled" {
  description = "Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion)"
  type        = bool
  default     = false
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = string
  default     = ""
}

variable "disable_cloudtrail" {
  description = "Used to specify that Cloudtrail is disabled."
  type        = bool
  default     = true
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
  default     = false
}

variable "app_bucket_expiration" {
  description = "The number of days to retain S3 app data before deleting"
  type        = number
  default     = 365
}

# cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS`"
  type        = string
  sensitive   = true
  default     = "dummy-cloudflare-tokens-must-be-40-chars"
}

variable "cloudflare_tunnel_enabled" {
  description = "Flag whether to enable Cloudflare Zero Trust tunnel for bastion"
  type        = bool
  default     = false
}

variable "cloudflare_tunnel_subdomain" {
  description = "Subdomain under the Cloudflare Zone to create the tunnel"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_zone_id" {
  description = "Zone ID for Cloudflare domain"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_email_domain" {
  description = "Email domain for Cloudflare access"
  type        = string
  sensitive   = true
  default     = "useparagon.com"
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
  default     = false
}

variable "msk_kafka_version" {
  description = "The Kafka version for the MSK cluster."
  type        = string
  // NOTE: to use a small instance type like `kafka.t3.small`, we need to use an older version that uses zookeeper
  // we're default to an older version to keep costs low, but we can override this if we use a supported larger instance type
  default = "3.6.0"
}

variable "msk_kafka_num_broker_nodes" {
  description = "The number of broker nodes for the MSK cluster."
  type        = number
  default     = 2
}

variable "msk_autoscaling_enabled" {
  description = "Whether to enable autoscaling for the MSK cluster."
  type        = bool
  default     = true
}

variable "msk_instance_type" {
  description = "The instance type for the MSK cluster."
  type        = string
  default     = "kafka.t3.small"
}

locals {
  # hash of account ID to help ensure uniqueness of resources like S3 bucket names
  hash        = substr(sha256(data.aws_caller_identity.current.account_id), 0, 8)
  environment = "enterprise"
  workspace   = "paragon-${var.organization}-${local.hash}"

  # NOTE hash and workspace can't be included in tags since it creates a circular reference
  default_tags = {
    Name         = "paragon-${var.organization}"
    Environment  = local.environment
    Organization = var.organization
    Creator      = "Terraform"
  }

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])

  # split instance types by comma, trim, and remove duplicates
  eks_ondemand_node_instance_type = distinct([for value in split(",", var.eks_ondemand_node_instance_type) : trimspace(value)])
  eks_spot_node_instance_type     = distinct([for value in split(",", var.eks_spot_node_instance_type) : trimspace(value)])
}
