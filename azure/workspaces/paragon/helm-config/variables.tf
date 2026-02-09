variable "base_helm_values" {
  description = "The base configuration for the values for the helm chart."
}

variable "infra_values" {
  description = "The values from the infrastructure workspace."
}

variable "domain" {
  description = "The domain of the application."
  type        = string
}

variable "microservices" {
  description = "The microservices to create monitors for."
  type        = map(any)
}

locals {
  postgres_instances = ["sync_instance", "sync_project", "openfga"]
}
