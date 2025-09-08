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

variable "logs_bucket_expiration" {
  description = "The number of days to retain S3 logs before deleting"
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}
