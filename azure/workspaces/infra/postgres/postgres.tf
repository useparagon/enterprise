resource "random_string" "postgres_root_username" {
  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = "${var.workspace}-postgres"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  administrator_login    = random_string.postgres_root_username.result
  administrator_password = random_password.postgres_root_password.result

  sku_name = var.postgres_sku_name
  version  = var.postgres_version

  auto_grow_enabled             = true
  backup_retention_days         = 7
  delegated_subnet_id           = azurerm_subnet.postgres.id
  geo_redundant_backup_enabled  = var.postgres_redundant
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  tags                          = merge(var.tags, { Name = "${var.workspace}-postgres" })

  high_availability {
    mode = var.postgres_redundant ? "ZoneRedundant" : "SameZone"
  }

  lifecycle {
    ignore_changes = [
      high_availability[0].standby_availability_zone,
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "paragon" {
  name      = "paragon"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# resource "azurerm_postgresql_virtual_network_rule" "private_subnet_access" {
#   name                = "${azurerm_postgresql_flexible_server.postgres.name}-private-subnet-access"
#   resource_group_name = var.resource_group.name
#   server_name         = azurerm_postgresql_flexible_server.postgres.name

#   subnet_id                            = var.private_subnet.id
#   ignore_missing_vnet_service_endpoint = false

#   depends_on = [azurerm_postgresql_flexible_server.postgres]
# }

# # Needed to allow Paragon migrations that use `dblink` to run
# resource "azurerm_postgresql_firewall_rule" "allow_dblink" {
#   name                = "allow_dblink"
#   resource_group_name = var.resource_group.name
#   server_name         = azurerm_postgresql_flexible_server.postgres.name

#   start_ip_address = "0.0.0.0"
#   end_ip_address   = "0.0.0.0"

#   depends_on = [azurerm_postgresql_flexible_server.postgres]
# }
