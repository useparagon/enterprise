variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "base_helm_values" {
  description = "The base configuration for the values for the helm chart."
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
