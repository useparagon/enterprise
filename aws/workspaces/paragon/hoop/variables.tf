variable "workspace" {
  description = "The workspace name."
  type        = string
}

variable "organization" {
  description = "The name of the organization that's deploying Paragon."
  type        = string
}

variable "cluster_name" {
  description = "The EKS cluster name."
  type        = string
}

variable "hoop_agent_id" {
  description = "Hoop agent ID for connections. Only used if hoop_enabled is true."
  type        = string
  default     = null
}

variable "hoop_api_key" {
  description = "Hoop API key. Only used if hoop_enabled is true."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_api_url" {
  description = "Hoop API URL."
  type        = string
  default     = "https://hoop.ops.paragoninternal.com/api"
}

variable "hoop_enabled" {
  description = "Whether to enable Hoop agent. hoop_key, hoop_api_key, and hoop_agent_id must be set if this is true."
  type        = bool
  default     = true
}

variable "hoop_key" {
  description = "Hoop agent key (token). Only used if hoop_enabled is true."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_server" {
  description = "Hoop gRPC server address."
  type        = string
  default     = "hoop-grpc.ops.paragoninternal.com:8443"
}

variable "hoop_version" {
  description = "The version of Hoop agent to install."
  type        = string
  default     = "1.49.0"
}

variable "customer_facing" {
  description = "Whether the connections are customer-facing (true limits access to dev-team-oncall/dev-team-managers/admin, false adds dev-team-engineering)."
  type        = bool
  default     = true
}

variable "all_access_groups" {
  description = "Additional access-control groups allowed when customer_facing is false."
  type        = list(string)
  default     = ["dev-team-engineering"]
}

variable "restricted_access_groups" {
  description = "Base access-control groups allowed for all connections."
  type        = list(string)
  default     = ["dev-team-oncall", "dev-team-managers", "admin"]
}

variable "reviewers_access_groups" {
  description = "Reviewer groups required for customer-facing app connections."
  type        = list(string)
  default     = ["dev-team-managers", "admin"]
}

variable "hoop_slack_bot_token" {
  description = "Slack bot token for the Hoop Slack plugin."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_slack_app_token" {
  description = "Slack app token for the Hoop Slack plugin."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_slack_channel_ids" {
  description = "Slack channel IDs to notify for connections that require reviews."
  type        = list(string)
  default     = []
}

variable "infra_vars" {
  description = "Infrastructure variables from infra-output.json."
  type = object({
    postgres = optional(object({
      value = optional(map(object({
        host     = string
        port     = number
        user     = string
        password = string
        database = string
        sslmode  = optional(string, "disable")
      })), {})
    }))
    redis = optional(object({
      value = optional(map(object({
        host      = string
        port      = number
        db_number = optional(number, 0)
      })), {})
    }))
  })
  default = {
    postgres = null
    redis    = null
  }
}

variable "namespace_paragon" {
  description = "Reference to kubernetes_namespace.paragon from helm module."
  type        = any
}

variable "custom_connections" {
  description = "Custom Hoop connections defined via tfvars. Map of connection names to their configuration."
  type = map(object({
    type                  = string           # "database", "application", or "custom"
    subtype               = optional(string) # e.g., "postgres", "redis", "tcp"
    access_mode_runbooks  = optional(string, "enabled")
    access_mode_exec      = optional(string, "enabled")
    access_mode_connect   = optional(string, "disabled")
    access_schema         = optional(string, "disabled")
    command               = optional(list(string)) # Required for "custom" type
    secrets               = map(string)            # Map of secret keys to values
    tags                  = optional(map(string), {})
    guardrail_rules       = optional(list(string), [])
    reviewers             = optional(list(string), [])
    access_control_groups = optional(list(string), [])
  }))
  default = {}
}

variable "k8s_connections" {
  description = "Kubernetes Hoop connections defined via tfvars. Map of connection names to their configuration. If empty, a default k8s-admin connection will be created."
  type = map(object({
    type                  = optional(string, "custom") # Usually "custom" for k8s connections
    subtype               = optional(string)
    access_mode_runbooks  = optional(string, "enabled")
    access_mode_exec      = optional(string, "enabled")
    access_mode_connect   = optional(string, "enabled")
    access_schema         = optional(string, "disabled")
    command               = optional(list(string), ["bash"])
    remote_url            = optional(string, "https://kubernetes.default.svc.cluster.local")
    insecure              = optional(string, "true")
    namespace             = optional(string, "paragon")
    secrets               = optional(map(string), {}) # Additional secrets beyond the token
    tags                  = optional(map(string), {})
    guardrail_rules       = optional(list(string), [])
    reviewers             = optional(list(string), [])
    access_control_groups = optional(list(string), [])
  }))
  default = {}
}
