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
