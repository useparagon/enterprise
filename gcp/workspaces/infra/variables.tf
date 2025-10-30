# credentials
variable "gcp_credential_json_file" {
  description = "The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided."
  type        = string
  default     = null
}

variable "gcp_project_id" {
  description = "The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`."
  type        = string
  default     = null
}

variable "gcp_private_key_id" {
  description = "The id of the private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_private_key" {
  description = "The private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_email" {
  description = "The client email for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_id" {
  description = "The client id for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_x509_cert_url" {
  description = "The client certificate url for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

# account
variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string

  validation {
    condition     = length(var.organization) <= 16
    error_message = "The `organization` input must be 16 or less characters."
  }
}

variable "environment" {
  description = "Type of environment being deployed to."
  type        = string
  default     = "enterprise"
}

variable "vpc_cidr" {
  description = "CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended."
  type        = string
  default     = "10.0.0.0/16"
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone" {
  description = "The zone in the region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone_backup" {
  description = "The backup zone in the region where to host Google Cloud Organization resources."
  type        = string
}

# cloudflare
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
  sensitive   = true
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

# optional network restrictions
variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = string
  default     = ""
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on database and storage resources."
  type        = bool
  default     = false
}

# postgres
variable "postgres_tier" {
  description = "The instance type to use for Postgres."
  type        = string
  default     = "db-custom-2-7680"
  # https://cloud.google.com/sql/docs/mysql/instance-settings#:~:text=see%20Instance%20Locations.-,Machine,-Type
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
}

# redis
variable "redis_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
  default     = true
}

variable "redis_memory_size" {
  description = "The size of the Redis instance (in GB)."
  type        = number
  default     = 2
}

# kubernetes
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.32"
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
  default     = 2
}

variable "k8s_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
  default     = 20
}

variable "k8s_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 80
  validation {
    condition     = var.k8s_spot_instance_percent >= 0 && var.k8s_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
  default     = "e2-standard-4"
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "e2-standard-4"
}

locals {
  creds_json     = try(jsondecode(file(var.gcp_credential_json_file)), {})
  gcp_project_id = try(local.creds_json.project_id, var.gcp_project_id)

  gcp_creds = jsonencode({
    type                        = "service_account",
    auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs",
    auth_uri                    = "https://accounts.google.com/o/oauth2/auth",
    token_uri                   = "https://oauth2.googleapis.com/token",
    client_email                = try(local.creds_json.client_email, var.gcp_client_email),
    client_id                   = try(local.creds_json.client_id, var.gcp_client_id),
    client_x509_cert_url        = try(local.creds_json.client_x509_cert_url, var.gcp_client_x509_cert_url),
    gcp_project_id              = try(local.creds_json.gcp_project_id, var.gcp_project_id),
    private_key                 = try(local.creds_json.private_key, var.gcp_private_key),
    private_key_id              = try(local.creds_json.private_key_id, var.gcp_private_key_id),
  })

  # hash of project ID to help ensure uniqueness of resources like bucket names
  hash      = substr(sha256(local.gcp_project_id), 0, 8)
  workspace = nonsensitive("paragon-${var.organization}-${local.hash}")

  default_labels = {
    name         = local.workspace
    environment  = var.environment
    organization = var.organization
    creator      = "terraform"
  }

  // get distinct values from comma-separated list, filter empty values and trim them
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])
}
