variable "gcp_project_id" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "network" {
  description = "The Virtual network  where our resources will be deployed"
}

variable "private_subnet" {
  description = "The private subnet in our virtual network"
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
}

variable "postgres_tier" {
  description = "The instance type to use for Postgres."
  type        = string
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
}

variable "auditlogs_lock_enabled" {
  description = "Whether to enable S3 Object Lock for the audit logs bucket."
  type        = bool
}

variable "managed_sync_enabled" {
  description = "Whether to create a dedicated Postgres instance for Managed Sync."
  type        = bool
  default     = false
}

locals {
  postgres_instances = var.postgres_multiple_instances ? merge({
    cerberus = {
      tier = "db-custom-1-3840"
    },
    eventlogs = {
      tier = "db-custom-2-7680"
    },
    hermes = {
      tier = var.postgres_tier
    },
    triggerkit = {
      tier = "db-custom-1-3840"
    },
    zeus = {
      tier = "db-custom-2-7680"
    }
    }, var.managed_sync_enabled ? {
    managed_sync = {
      tier = "db-custom-2-7680"
    }
    } : {}) : {
    paragon = {
      tier = var.postgres_tier
    }
  }
}
