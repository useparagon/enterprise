output "tokens" {
  description = "Hoop ServiceAccount tokens for cluster access."
  value = var.hoop_enabled ? {
    cluster_admin = try(data.kubernetes_secret_v1.hoop_cluster_admin_token[0].data["token"], "")
  } : null
  sensitive = true
}
