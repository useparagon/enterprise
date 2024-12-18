variable "app_name" {
  description = "An optional name to override the name of the resources created."
}

variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "private_subnet" {
  description = "The private subnet(s) within the VPC."
}

variable "public_subnet" {
  description = "The public subnet(s) within the VPC."
}

# Azure has an option to autoscale Postgres size. However once you provision a certain size, you can't scale down.
# This configuration is a legacy configuration to support Azure instances provisioned before 2022-07-24 which originally had `640000` mb provisioned.
# This was lowered to reduce initial costs of running Paragon on-prem.
variable "postgres_storage_mb" {
  description = "How many megabytes to initially provision for the Postgres instance."
  type        = number
}
