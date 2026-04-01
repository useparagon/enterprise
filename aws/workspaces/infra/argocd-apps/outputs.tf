output "all_manifests" {
  description = "Flat list of all YAML manifests (ArgoCD Applications + ExternalSecrets) to be applied via SSM."
  value       = concat(values(local.all_external_secrets), values(local.all_applications))
}
