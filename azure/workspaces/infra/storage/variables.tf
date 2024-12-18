variable "app_name" {
  description = "An optional name to override the name of the resources created."
}

variable "microservices" {
  description = "The microservices running in the installation."
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

locals {
  storage_account_name   = replace("paragon-storage-${random_string.storage_hash.result}", "/\\W|_|\\s/", "")
  private_container_name = "${var.app_name}-app"
  public_container_name  = "${var.app_name}-cdn"
}
