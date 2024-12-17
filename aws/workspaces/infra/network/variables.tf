variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "az_count" {
  description = "Number of AZs to cover in a given region."
  type        = number
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets."
  type        = number
}
