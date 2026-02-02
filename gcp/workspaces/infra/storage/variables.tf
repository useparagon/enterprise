variable "gcp_project_id" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
}

variable "auditlogs_lock_enabled" {
  description = "Whether to lock the GCS audit logs bucket retention policy."
  type        = bool
}

variable "use_storage_account_key" {
  description = "Whether to use the storage service account privatekey for the storage service account."
  type        = bool
}
