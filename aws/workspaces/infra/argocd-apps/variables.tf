variable "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  type        = string
  default     = "argocd"
}

variable "destination_namespace" {
  description = "Target namespace for Paragon workloads."
  type        = string
  default     = "paragon"
}

variable "chart_repository" {
  description = "OCI or HTTPS Helm chart repository URL."
  type        = string
}

variable "chart_version" {
  description = "Target chart version or constraint (e.g. '2026.04.*')."
  type        = string
}

variable "workspace" {
  description = "Workspace name used in Application naming."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for ExternalSecrets."
  type        = string
}

variable "env_secret_name" {
  description = "Secrets Manager secret name for environment config."
  type        = string
}

variable "docker_cfg_secret_name" {
  description = "Secrets Manager secret name for Docker credentials."
  type        = string
}

variable "managed_sync_secret_name" {
  description = "Secrets Manager secret name for managed sync config (null if disabled)."
  type        = string
  default     = null
}

variable "openobserve_secret_name" {
  description = "Secrets Manager secret name for OpenObserve credentials (null if not created)."
  type        = string
  default     = null
}

variable "managed_sync_enabled" {
  description = "Whether managed sync is enabled."
  type        = bool
  default     = false
}

variable "managed_sync_version" {
  description = "Helm chart version for managed-sync."
  type        = string
  default     = "latest"
}

variable "managed_sync_repository" {
  description = "Helm chart repository for managed-sync."
  type        = string
  default     = "https://paragon-helm-production.s3.amazonaws.com"
}

variable "monitors_enabled" {
  description = "Whether monitoring is enabled."
  type        = bool
  default     = false
}

variable "monitor_version" {
  description = "Chart version for the monitoring stack."
  type        = string
  default     = "latest"
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the cluster-autoscaler IRSA service account."
  type        = string
}

variable "ingress_chart_version" {
  description = "Version of the AWS Load Balancer Controller chart."
  type        = string
  default     = "1.9.1"
}

variable "metrics_server_chart_version" {
  description = "Version of the metrics-server chart."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "logs_bucket" {
  description = "S3 bucket for system logs."
  type        = string
}

variable "ingress_scheme" {
  description = "ALB scheme: internet-facing or internal."
  type        = string
  default     = "internet-facing"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the ingress."
  type        = string
  default     = ""
}

variable "auto_sync" {
  description = "Whether to enable automatic sync on ArgoCD Applications."
  type        = bool
  default     = true
}

variable "self_heal" {
  description = "Whether to enable self-healing (drift correction)."
  type        = bool
  default     = true
}
