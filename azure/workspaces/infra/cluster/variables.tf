variable "app_name" {
  description = "An optional name to override the name of the resources created."
}

variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "location" {
  description = "The Azure region resources are created in."
}

variable "private_subnet" {
  description = "The private subnet(s) within the VPC."
}

variable "domain" {
  description = "The domain used for the application. Used to generate an SSL certificate and associates CNAMEs."
}

variable "public_subnet" {
  description = "The public subnet(s) within the VPC."
}

variable "config_hash" {
  description = "Checksum of the cache directory. Used to determine whether the microservices need to be restarted."
  type        = string
}

variable "docker_username" {
  description = "Docker username to pull images."
  type        = string
}

variable "docker_password" {
  description = "Docker password to pull images."
  type        = string
}

variable "docker_registry_server" {
  description = "EKS cluster auth token"
  default     = "docker.io"
}

variable "docker_email" {
  description = "Docker email to pull images."
  type        = string
}

variable "paragon_version" {
  description = "The version of paragon to install"
}

variable "deployment_cache_buster" {
  description = "Cache buster to force new deployments incase `config_hash` doesn't change."
  type        = string
  default     = null
}

variable "microservices" {
  description = "The microservices running within the system."
  type = map(object({
    acl              = string
    port             = number
    healthcheck_path = string
    vm               = string
    public_url       = string
  }))
}

variable "monitors" {
  description = "The monitors running in the installation."
  type = map(object({
    port       = number
    vm         = string
    public_url = string
  }))
}
variable "cloudflare_dns_api_token" {
  description = "Cloudflare DNS API token for SSL certificate creation and verification."
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id to set CNAMEs."
}

locals {

  domain_parts = split(".", var.domain)
  # If the domain has a cname (e.g. "subdomain.example.com") then we'll strip it to its naked domain (e.g. "example.com")
  naked_domain = length(local.domain_parts) > 1 ? join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts))) : var.domain

}

variable "monitoring_helm_hash" {
  description = "Checksum of the monitoring helm chart."
  type        = string
}

variable "onprem_helm_hash" {
  description = "Checksum of the onprem helm chart."
  type        = string
}

variable "logging_helm_hash" {
  description = "Checksum of the logging helm chart."
  type        = string
}

variable "k8_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "k8_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
}

variable "k8_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
}

variable "k8_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
}

variable "k8_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
}

variable "k8_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
}

variable "beethoven_postgres_port" {
  description = "Beethoven Postgres Port"
  type        = number
}
