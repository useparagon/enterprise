variable "base_helm_values" {
  description = "The base configuration for the values for the helm chart."
  type        = any
}

variable "infra_values" {
  description = "The values from the infrastructure workspace (from infra-output.json)."
  type        = any
}

variable "domain" {
  description = "The domain of the application."
  type        = string
}

variable "microservices" {
  description = "The microservices used for managed-sync URLs (api-sync, worker-proxy, zeus, queue-exporter)."
  type        = map(any)
}

variable "region" {
  description = "Optional GCP region for storage URLs."
  type        = string
  default     = null
}

variable "gcp_storage_sa_key" {
  description = "GCP service account key JSON for cloud storage (CLOUD_STORAGE_PASS). When set, used for managed-sync when storage type is GCP so the same credential as paragon is passed."
  type        = string
  default     = null
  sensitive   = true
}

locals {
  postgres_instances = ["sync_instance", "sync_project", "openfga"]
}
