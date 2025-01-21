variable "gcp_project_id" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "network" {
  description = "The Virtual network  where our resources will be deployed"
}

variable "private_subnet" {
  description = "The private subnet in our virtual network"
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
}

locals {
  postgres_instances = {
    cerberus = {
      tier = "db-f1-micro"
    },
    hermes = {
      tier = "db-custom-2-7680" // e.g. "db-n1-standard-2"
    },
    pheme = {
      tier = "db-f1-micro"
    },
    zeus = {
      tier = "db-custom-2-7680" // e.g. "db-n1-standard-2"
    }
  }
}
