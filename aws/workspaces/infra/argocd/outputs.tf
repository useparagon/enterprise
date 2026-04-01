output "argocd_namespace" {
  description = "The namespace ArgoCD is installed in."
  value       = var.argocd_namespace
}

output "eso_role_arn" {
  description = "IAM role ARN used by the External Secrets Operator."
  value       = aws_iam_role.eso.arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for AWS Secrets Manager."
  value       = "aws-secrets-manager"
}

output "ssm_document_name" {
  description = "Name of the SSM document used for bootstrap."
  value       = aws_ssm_document.argocd_bootstrap.name
}
