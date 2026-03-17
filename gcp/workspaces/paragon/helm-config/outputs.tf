output "config" {
  description = "Managed sync env vars to merge into helm_values.global.env."
  value       = local.managed_sync_secrets
  sensitive   = true
}
