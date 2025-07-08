variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network" {
  description = "The virtual network to deploy to."
}

variable "private_subnet" {
  description = "Private subnet that can access redis."
}

variable "public_subnet" {
  description = "The public subnet(s) within the VPC."
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "redis_subnet" {
  description = "Private subnet accessible only within the virtual network to deploy to."
}

variable "redis_capacity" {
  description = "The capacity of the Redis cache."
  type        = number
}

variable "redis_base_capacity" {
  description = "Default capacity of the Redis cache for instances that don't use the main redis_capacity."
  type        = number
}

variable "redis_sku_name" {
  description = "The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`)."
  type        = string
}

variable "redis_base_sku_name" {
  description = "Default SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`) for instances that don't use the main redis_sku_name."
  type        = string
}

variable "redis_ssl_only" {
  description = "Flag whether only SSL connections are allowed."
  type        = bool
}

variable "redis_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
}

locals {
  redis_instances = var.redis_multiple_instances ? {
    cache = {
      cluster  = var.redis_sku_name == "Premium"
      capacity = var.redis_capacity
      sku      = var.redis_sku_name
    }
    queue = {
      cluster  = false
      capacity = var.redis_base_capacity
      sku      = var.redis_base_sku_name
    }
    system = {
      cluster  = false
      capacity = var.redis_base_capacity
      sku      = var.redis_base_sku_name
    }
    } : {
    cache = {
      cluster  = false
      capacity = var.redis_capacity
      sku      = var.redis_sku_name
    }
  }
}
