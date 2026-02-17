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
}

variable "region_zone" {
  description = "The zone in the region where to host Google Cloud Organization resources."
}

variable "region_zone_backup" {
  description = "The backup zone in the region where to host Google Cloud Organization resources."
}

variable "multi_redis" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
}

variable "redis_memory_size" {
  description = "The size of the Redis instance (in GB)."
  type        = number
}

variable "managed_sync_enabled" {
  description = "Whether to create a dedicated Redis instance for Managed Sync."
  type        = bool
  default     = false
}

locals {
  redis_instances = var.multi_redis ? merge({
    cache = {
      cluster = true
      size    = var.redis_memory_size
    }
    queue = {
      cluster = false
      size    = 1
    }
    system = {
      cluster = false
      size    = 1
    }
    }, var.managed_sync_enabled ? {
    managed_sync = {
      cluster = false
      size    = 1
    }
    } : {}) : {
    cache = {
      cluster = false
      size    = var.redis_memory_size
    }
  }

  # GCP instance_id max 40 chars. Use full name if it fits; else truncate workspace to 25.
  redis_name_suffix = {
    for k, v in local.redis_instances : k => (k == "managed_sync" ? "-redis-sync" : "-redis-${k}")
  }
  redis_instance_name = {
    for k, v in local.redis_instances : k => (
      length("${var.workspace}${local.redis_name_suffix[k]}") <= 40
      ? "${var.workspace}${local.redis_name_suffix[k]}"
      : "${substr(var.workspace, 0, 25)}${local.redis_name_suffix[k]}"
    )
  }
}
