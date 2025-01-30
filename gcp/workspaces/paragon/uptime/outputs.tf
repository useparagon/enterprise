output "webhook" {
  value     = local.enabled ? betteruptime_grafana_integration.webhook[0].webhook_url : ""
  sensitive = true
}
