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
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "The capacity for the redis instance. It must be between 0 - 6 (inclusive)."
  }
}

variable "redis_sku_name" {
  description = "The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`)."
  type        = string
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "The sku_name for the redis instance. It must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_ssl_only" {
  description = "Flag whether only SSL connections are allowed."
  type        = bool
  default     = true
}
