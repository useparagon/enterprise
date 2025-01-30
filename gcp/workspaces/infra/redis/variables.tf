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

locals {
  redis_instances = var.multi_redis ? {
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
    } : {
    cache = {
      cluster = false
      size    = var.redis_memory_size
    }
  }
}
