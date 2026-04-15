variable "recovery_window_in_days" {
  description = "Days before Secrets Manager permanently deletes a secret after destroy. Use 0 for immediate deletion so the same secret name can be recreated (e.g. ephemeral stacks). Production values are typically 7–30."
  type        = number
}

variable "workspace" {
  description = "Workspace name used for Secrets Manager path prefix."
  type        = string
}

variable "organization" {
  description = "Organization name for the secret path."
  type        = string
}

variable "env_config" {
  description = "Map of environment variable key-value pairs to store as the primary paragon secret."
  type        = map(string)
  sensitive   = true
}

variable "docker_config" {
  description = "Docker registry credentials as a JSON-encoded dockerconfigjson."
  type        = string
  sensitive   = true
}

variable "managed_sync_config" {
  description = "Optional managed-sync secret data. Null when managed sync is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "openobserve_credentials" {
  description = "OpenObserve admin credentials."
  type = object({
    email    = string
    password = string
  })
  sensitive = true
  default   = null
}
