resource "random_string" "grafana_admin_email_prefix" {
  count = var.grafana_admin_email == null && var.grafana_admin_password == null ? 1 : 0

  length  = 16
  special = false
  numeric = false
  lower   = true
  upper   = false
}

resource "random_password" "grafana_admin_password" {
  count = var.grafana_admin_email == null && var.grafana_admin_password == null ? 1 : 0

  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 0
  numeric     = true
  special     = false
  lower       = true
  upper       = true
}
