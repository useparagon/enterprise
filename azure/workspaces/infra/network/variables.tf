variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
}

variable "location" {
  description = "The Azure region resources are created in."
  type        = string
}
