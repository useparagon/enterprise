variable "workspace" {
  description = "The name of the workspace resources are being created in."
}

variable "force_destroy" {
  description = "Whether to enable force destroy."
  type        = bool
}

variable "app_bucket_expiration" {
  description = "The number of days to retain S3 app data before deleting"
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
}

variable "auditlogs_lock_enabled" {
  description = "Whether to enable S3 Object Lock for the audit logs bucket."
  type        = bool
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}

variable "migrated" {
  description = "Whether the workspace is being migrated from a legacy workspace."
  type        = bool
  default     = false
}
