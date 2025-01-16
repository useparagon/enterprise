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
  description = "Whether zone redundant HA should be enabled"
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

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances."
  type        = bool
}

locals {
  postgres_instances = var.postgres_multiple_instances ? {
    cerberus = {
      name = "${var.workspace}-cerberus"
      db   = "cerberus"
      ha   = false
      sku  = "B_Standard_B1ms"
    }
    hermes = {
      name = "${var.workspace}-hermes"
      db   = "hermes"
      ha   = var.postgres_redundant
      sku  = var.postgres_sku_name
    }
    zeus = {
      name = "${var.workspace}-zeus"
      db   = "zeus"
      ha   = false
      sku  = "B_Standard_B2s"
    }
    } : {
    paragon = {
      name = "${var.workspace}"
      db   = "postgres"
      ha   = var.postgres_redundant
      sku  = var.postgres_sku_name
    }
  }
}
