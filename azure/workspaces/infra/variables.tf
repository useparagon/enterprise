variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

# Optional service principal for the azurerm / azuread providers when this workspace is
# the Terraform root. Leave null (omit in tfvars) to use ARM_* / Azure CLI / OIDC.
# When this path is used as a child module, omit these so the parent workspace owns
# provider auth (same env-based chain).
variable "azure_tenant_id" {
  description = "Azure AD tenant ID for provider auth. Optional if using ARM_TENANT_ID / CLI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure AD application (client) ID for provider auth. Optional if using ARM_CLIENT_ID / CLI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure AD client secret for provider auth. Optional if using ARM_CLIENT_SECRET / CLI."
  type        = string
  default     = null
  nullable    = true
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

variable "environment" {
  description = "Type of environment being deployed to."
  type        = string
  default     = "enterprise"
  nullable    = false
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist SSH access."
  type        = string
  default     = ""
  nullable    = false
}

variable "bastion_vm_size" {
  description = "VM size for the bastion scale set (e.g. Standard_B1s). Must be available in the target region."
  type        = string
  default     = "Standard_B1s"
  nullable    = false
}

variable "vpc_cidr" {
  description = "CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
  default     = 365
  nullable    = false
}

variable "auditlogs_lock_enabled" {
  description = "Whether to lock the audit logs container immutability policy."
  type        = bool
  default     = false
  nullable    = false
}

# cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS`"
  type        = string
  sensitive   = true
  default     = "dummy-cloudflare-tokens-must-be-40-chars"
  nullable    = false
}

variable "cloudflare_tunnel_enabled" {
  description = "Flag whether to enable Cloudflare Zero Trust tunnel for bastion"
  type        = bool
  default     = false
  nullable    = false
}

variable "cloudflare_tunnel_subdomain" {
  description = "Subdomain under the Cloudflare Zone to create the tunnel"
  type        = string
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_zone_id" {
  description = "Zone ID for Cloudflare domain"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_email_domain" {
  description = "Email domain for Cloudflare access"
  type        = string
  sensitive   = true
  default     = "useparagon.com"
  nullable    = false
}

# postgres
variable "postgres_redundant" {
  description = "Whether zone redundant HA should be enabled"
  type        = bool
  default     = false
  nullable    = false
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU name (e.g. `B_Standard_B2s` or `GP_Standard_D2ds_v5`)"
  type        = string
  default     = "GP_Standard_D2ds_v5"
  nullable    = false
}

variable "postgres_base_sku_name" {
  description = "Default PostgreSQL SKU name for instances that don't use the main postgres_sku_name (e.g. `B_Standard_B2s` or `GP_Standard_D2ds_v5`)"
  type        = string
  default     = "B_Standard_B2s"
  nullable    = false
}

variable "postgres_version" {
  description = "PostgreSQL version (14, 15 or 16)"
  type        = string
  default     = "14"
  nullable    = false
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

# redis
variable "redis_capacity" {
  description = "Used to configure the capacity of the Redis cache."
  type        = number
  default     = 1
  nullable    = false
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "The capacity for the redis instance. It must be between 0 - 6 (inclusive)."
  }
}

variable "redis_base_capacity" {
  description = "Default capacity of the Redis cache for instances that don't use the main redis_capacity."
  type        = number
  default     = 1
  nullable    = false
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_base_capacity)
    error_message = "The capacity for the redis instance. It must be between 0 - 6 (inclusive)."
  }
}

variable "redis_sku_name" {
  description = "The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`)."
  type        = string
  default     = "Premium"
  nullable    = false
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "The sku_name for the redis instance. It must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_base_sku_name" {
  description = "Default SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`) for instances that don't use the main redis_sku_name."
  type        = string
  default     = "Standard"
  nullable    = false
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_base_sku_name)
    error_message = "The sku_name for the redis instance. It must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_ssl_only" {
  description = "Flag whether only SSL connections are allowed."
  type        = bool
  default     = false
  nullable    = false
}

variable "redis_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
  default     = true
  nullable    = false
}

# aks
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.33"
  nullable    = false
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
  default     = 3
  nullable    = false
}

variable "k8s_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
  default     = 20
  nullable    = false
}

variable "k8s_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 75
  nullable    = false
  validation {
    condition     = var.k8s_spot_instance_percent >= 0 && var.k8s_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "k8s_default_node_pool_vm_size" {
  description = "VM size for the AKS default (system) node pool. Must be available in the target region (e.g. Standard_B2s_v2 in japaneast)."
  type        = string
  default     = "Standard_B2s"
  nullable    = false
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
  default     = "Standard_B2ms"
  nullable    = false
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "Standard_B2ms"
  nullable    = false
}

variable "k8s_sku_tier" {
  description = "The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`)."
  type        = string
  default     = "Premium"
  nullable    = false
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.k8s_sku_tier)
    error_message = "The sku_tier for the AKS cluster. It must be `Free`, `Standard`, or `Premium`."
  }
}

variable "storage_account_tier" {
  description = "Storage account tier. Use \"Standard\" for new deployments that need public CDN container access (Premium BlockBlobStorage does not support it)."
  type        = string
  default     = "Premium"
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
  default     = false
  nullable    = false
}

variable "eventhub_namespace_sku" {
  description = "The SKU name for the Event Hubs namespace (Basic, Standard, Premium)."
  type        = string
  default     = "Standard"
  nullable    = false
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.eventhub_namespace_sku)
    error_message = "The sku_name must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "eventhub_capacity" {
  description = "The capacity units for the Event Hubs namespace (1-20 for Standard, 1-8 for Premium)."
  type        = number
  default     = 1
  nullable    = false
  validation {
    condition     = var.eventhub_capacity >= 1 && var.eventhub_capacity <= 20
    error_message = "The capacity must be between 1 and 20."
  }
}

variable "eventhub_auto_inflate_enabled" {
  description = "Whether to enable auto-inflate for the Event Hubs namespace."
  type        = bool
  default     = true
  nullable    = false
}

variable "eventhub_maximum_throughput_units" {
  description = "The maximum throughput units for auto-inflate (only applicable when auto_inflate_enabled is true)."
  type        = number
  default     = 20
  nullable    = false
}

locals {
  # hash of subscription ID to help ensure uniqueness of resources like bucket names
  hash      = substr(sha256(var.azure_subscription_id), 0, 8)
  workspace = nonsensitive("paragon-${var.organization}-${local.hash}")

  default_tags = {
    Name         = local.workspace
    Environment  = var.environment
    Organization = var.organization
    Creator      = "Terraform"
  }

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])
}
