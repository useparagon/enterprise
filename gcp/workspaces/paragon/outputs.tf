output "grafana_admin_email" {
  description = "Grafana admin login email."
  value       = var.monitors_enabled ? module.monitors[0].grafana_admin_email : null
  sensitive   = true
}

output "grafana_admin_password" {
  description = "Grafana admin login password."
  value       = var.monitors_enabled ? module.monitors[0].grafana_admin_password : null
  sensitive   = true
}

output "pgadmin_admin_email" {
  description = "PGAdmin admin login email."
  value       = var.monitors_enabled ? module.monitors[0].pgadmin_admin_email : null
  sensitive   = true
}

output "pgadmin_admin_password" {
  description = "PGAdmin admin login password."
  value       = var.monitors_enabled ? module.monitors[0].pgadmin_admin_password : null
  sensitive   = true
}

output "uptime_webhook" {
  description = "Uptime webhook URL"
  value       = module.uptime.webhook
  sensitive   = true
}
