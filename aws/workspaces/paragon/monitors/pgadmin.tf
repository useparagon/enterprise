resource "random_string" "pgadmin_admin_email_prefix" {
  count = var.pgadmin_admin_email == null && var.pgadmin_admin_password == null ? 1 : 0

  length  = 16
  special = false
  numeric = false
  lower   = true
  upper   = false
}

resource "random_string" "pgadmin_admin_password" {
  count = var.pgadmin_admin_email == null && var.pgadmin_admin_password == null ? 1 : 0

  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 2
  numeric     = true
  special     = false
  lower       = true
  upper       = true
}
