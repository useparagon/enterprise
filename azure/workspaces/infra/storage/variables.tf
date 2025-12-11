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

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}
