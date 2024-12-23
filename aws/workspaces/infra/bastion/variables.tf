variable "workspace" {
  description = "The name of the workspace resources are being created in."
}

variable "aws_region" {
  description = "The AWS region resources are created in."
}

variable "vpc_id" {
  description = "The id of the VPC to create resources in."
}

variable "public_subnet" {
  description = "Public subnet accessible to the outside world."
}

variable "private_subnet" {
  description = "Private subnet accessible only within the VPC."
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = list(string)
}

# Cloudflare variables
variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS`"
  type        = string
  sensitive   = true
  default     = "dummy-cloudflare-tokens-must-be-40-chars"
}

variable "cloudflare_tunnel_enabled" {
  description = "Flag whether to enable Cloudflare Zero Trust tunnel for bastion"
  type        = bool
  default     = false
}

variable "cloudflare_tunnel_subdomain" {
  description = "Subdomain under the Cloudflare Zone to create the tunnel"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_zone_id" {
  description = "Zone ID for Cloudflare domain"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_email_domain" {
  description = "Email domain for Cloudflare access"
  type        = string
  sensitive   = true
  default     = "useparagon.com"
}

variable "cluster_name" {
  description = "The EKS cluster that node groups and resources should be deployed to."
  type        = string
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

locals {
  # TODO: update to random port
  ssh_port = 22
}
