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

variable "use_storage_account_key" {
  description = "Whether to use the storage service account privatekey for the storage service account."
  type        = bool
}
