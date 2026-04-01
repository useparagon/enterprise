variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster."
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL of the OIDC issuer for the EKS cluster."
  type        = string
}

variable "workspace" {
  description = "Workspace name used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the Secrets Manager resources."
  type        = string
}

variable "bastion_asg_name" {
  description = "Name of the bastion Auto Scaling Group (used for SSM tag-based targeting)."
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD into."
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD release version (e.g. v2.14.11). Used to download the install manifest."
  type        = string
  default     = "v2.14.11"
}

variable "eso_chart_version" {
  description = "Helm chart version for external-secrets."
  type        = string
  default     = "0.14.4"
}

variable "secrets_manager_secret_arns" {
  description = "List of Secrets Manager secret ARNs that ESO should be allowed to read."
  type        = list(string)
  default     = []
}

variable "argocd_application_manifests" {
  description = "List of YAML manifests (ArgoCD Applications + ExternalSecrets) to apply after bootstrap."
  type        = list(string)
  default     = []
}

variable "slack_token" {
  description = "Optional Slack bot token for ArgoCD notifications."
  type        = string
  sensitive   = true
  default     = null
}

variable "slack_channel" {
  description = "Slack channel for ArgoCD sync notifications."
  type        = string
  default     = ""
}
