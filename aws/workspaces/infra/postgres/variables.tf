variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "vpc" {
  description = "The VPC to create resources in."
}

variable "public_subnet" {
  description = "The public subnets within the VPC."
}

variable "private_subnet" {
  description = "The private subnets within the VPC."
}

variable "availability_zones" {
  description = "The AWS zones that are currently availabile."
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
}

variable "rds_instance_class" {
  description = "The RDS instance class type used for Postgres."
}

variable "disable_deletion_protection" {
  description = "Whether to disable deletion protection."
  type        = bool
}

variable "rds_multi_az" {
  description = "Whether or not multi-az is enabled."
  type        = bool
}

variable "rds_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances."
  type        = bool
}

locals {
  postgres_instances = var.rds_multiple_instances ? {
    cerberus = {
      name = "${var.workspace}-cerberus"
      size = "db.t4g.micro"
      db   = "cerberus"
    }
    hermes = {
      name = "${var.workspace}-hermes"
      size = var.rds_instance_class
      db   = "hermes"
    }
    zeus = {
      name = "${var.workspace}-zeus"
      size = "db.t4g.small"
      db   = "zeus"
    }
    } : {
    paragon = {
      name = "${var.workspace}"
      size = var.rds_instance_class
      db   = "postgres"
    }
  }
}
