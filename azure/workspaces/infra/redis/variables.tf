variable "app_name" {
  description = "An optional name to override the name of the resources created."
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
}

variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network" {
  description = "The virtual network to create resources in."
}

variable "private_subnet" {
  description = "The private subnet(s) within the VPC."
}

variable "public_subnet" {
  description = "The public subnet(s) within the VPC."
}

variable "redis_capacity" {
  description = "Used to configure the capacity of the Redis cache."
  type        = number
  validation {
    condition     = contains([1, 2, 3, 4, 5], var.redis_capacity)
    error_message = "The capacity for the redis instance. It must be between 1 - 5 (inclusive)."
  }
}
