resource "random_string" "postgres_root_username" {
  for_each = local.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = local.postgres_instances

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  for_each = local.postgres_instances

  name                = each.value.name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  administrator_login    = random_string.postgres_root_username[each.key].result
  administrator_password = random_password.postgres_root_password[each.key].result

  sku_name = each.value.sku
  version  = var.postgres_version

  auto_grow_enabled             = true
  backup_retention_days         = 7
  delegated_subnet_id           = var.private_subnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  tags                          = merge(var.tags, { Name = "${var.workspace}-postgres" })

  dynamic "high_availability" {
    for_each = each.value.ha ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  lifecycle {
    ignore_changes = [
      high_availability[0].standby_availability_zone,
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  for_each = local.postgres_instances

  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.postgres[each.key].id
  value     = "dblink,pg_cron,uuid-ossp"
}

resource "azurerm_postgresql_flexible_server_database" "paragon" {
  for_each = local.postgres_instances

  name      = each.value.db
  server_id = azurerm_postgresql_flexible_server.postgres[each.key].id
  collation = "en_US.utf8"
  charset   = "UTF8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.extensions]
}
