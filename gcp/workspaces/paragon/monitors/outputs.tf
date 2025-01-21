output "grafana_admin_email" {
  description = "Grafana admin login email."
  value       = var.grafana_admin_email != null ? var.grafana_admin_email : "${random_string.grafana_admin_email_prefix[0].result}@useparagon.com"
}

output "grafana_admin_password" {
  description = "Grafana admin login password."
  value       = var.grafana_admin_password != null ? var.grafana_admin_password : random_password.grafana_admin_password[0].result
}

output "pgadmin_admin_email" {
  description = "PGAdmin admin login email."
  value       = var.pgadmin_admin_email != null ? var.pgadmin_admin_email : "${random_string.pgadmin_admin_email_prefix[0].result}@useparagon.com"
}

output "pgadmin_admin_password" {
  description = "PGAdmin admin login password."
  value       = var.pgadmin_admin_password != null ? var.pgadmin_admin_password : random_password.pgadmin_admin_password[0].result
}
