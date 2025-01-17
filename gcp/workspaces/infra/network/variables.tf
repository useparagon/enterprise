variable "workspace" {
  description = "The name of the workspace resources are being created in"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resourcess"
  type        = string
}

variable "gcp_project_id" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets"
  type        = number
  default     = 1
}

variable "pod_cidr" {
  description = "Subnet CIDR for the pods"
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Subnet CIDR for the services"
  type        = string
  default     = "152.100.0.0/16"
}
