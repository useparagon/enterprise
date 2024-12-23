variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network" {
  description = "The virtual network to deploy to."
}

variable "private_subnet" {
  description = "Private subnet accessible only within the virtual network to deploy to."
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "postgres_redundant" {
  description = "Whether zone redundant HA should be enabled (location must support it)"
  type        = bool
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL version (14, 15 or 16)"
  type        = string
}
