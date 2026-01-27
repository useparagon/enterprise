variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network_subnet_ids" {
  description = "The subnets within the virtual network that will have storage access."
  type        = list(string)
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
}

variable "auditlogs_lock_enabled" {
  description = "Whether to lock the audit logs container immutability policy."
  type        = bool
}
