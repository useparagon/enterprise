variable "workspace" {
  description = "The workspace name."
  type        = string
}

variable "organization" {
  description = "The name of the organization that's deploying Paragon."
  type        = string
}

variable "cluster_host" {
  description = "The GKE cluster host endpoint."
  type        = string
}

variable "cluster_token" {
  description = "The GKE cluster access token."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "The GKE cluster CA certificate (base64 encoded)."
  type        = string
}

variable "hoop_enabled" {
  description = "Whether to enable Hoop agent."
  type        = bool
  default     = true
}

variable "hoop_version" {
  description = "The version of Hoop agent to install."
  type        = string
  default     = "1.47.2"
}

variable "hoop_server" {
  description = "Hoop gRPC server address."
  type        = string
  default     = "hoop-grpc.ops.paragoninternal.com:8443"
}

variable "hoop_key" {
  description = "Hoop agent key (token)."
  type        = string
  sensitive   = true
  default     = null
}

variable "hoop_namespace" {
  description = "Kubernetes namespace for Hoop agent."
  type        = string
  default     = "hoopagent"
}
