# credentials
variable "azure_client_id" {
  description = "Azure client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure client secret"
  type        = string
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive   = true
}

# account
variable "location" {
  description = "Azure geographic region to deploy resources in."
  type        = string
}

variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist SSH access."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended."
  type        = string
  default     = "10.0.0.0/16"
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

# postgres
variable "postgres_redundant" {
  description = "Whether zone redundant HA should be enabled (region must support it and many don't)"
  type        = bool
  default     = false
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "GP_Standard_D2ds_v5"
}

variable "postgres_version" {
  description = "PostgreSQL version (14, 15 or 16)"
  type        = string
  default     = "14"
}

# redis
variable "redis_capacity" {
  description = "Used to configure the capacity of the Redis cache."
  type        = number
  default     = 1
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "The capacity for the redis instance. It must be between 0 - 6 (inclusive)."
  }
}

variable "redis_sku_name" {
  description = "The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`)."
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "The sku_name for the redis instance. It must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_ssl_only" {
  description = "Flag whether only SSL connections are allowed."
  type        = bool
  default     = false
}

variable "redis_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
  default     = true
}

# aks
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.31"
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
  default     = 3
}

variable "k8s_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
  default     = 20
}

variable "k8s_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 75
  validation {
    condition     = var.k8s_spot_instance_percent >= 0 && var.k8s_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
  default     = "Standard_B2ms"
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "Standard_B2ms"
}

variable "k8s_sku_tier" {
  description = "The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`)."
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.k8s_sku_tier)
    error_message = "The sku_tier for the AKS cluster. It must be `Free`, `Standard`, or `Premium`."
  }
}

locals {
  # hash of subscription ID to help ensure uniqueness of resources like bucket names
  hash        = substr(sha256(var.azure_subscription_id), 0, 8)
  environment = "enterprise"
  workspace   = nonsensitive("paragon-${var.organization}-${local.hash}")

  default_tags = {
    Name         = local.workspace
    Environment  = local.environment
    Organization = var.organization
    Creator      = "Terraform"
  }

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])
}
