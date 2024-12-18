resource "random_string" "postgres_root_username" {
  length  = 16
  special = false
  number  = false
  lower   = true
  upper   = true
}

resource "random_string" "postgres_root_password" {
  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 2
  number      = true
  special     = false
  lower       = true
  upper       = true
}

# Create Postgres server
resource "azurerm_postgresql_server" "postgresserver" {
  name                = "${var.app_name}-postgresserver"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  administrator_login          = random_string.postgres_root_username.result
  administrator_login_password = random_string.postgres_root_password.result

  sku_name   = "GP_Gen5_2"
  version    = "11"
  storage_mb = var.postgres_storage_mb

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled = true
  ssl_enforcement_enabled       = false
  # Disabled because `ssl_enforcement_enabled` is disabled due to current TypeORM settings in monorepo
  # ssl_minimal_tls_version_enforced = "TLS1_2"
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

# Create Postgres Database
resource "azurerm_postgresql_database" "paragon" {
  name                = "paragon"
  resource_group_name = var.resource_group.name
  server_name         = azurerm_postgresql_server.postgresserver.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_virtual_network_rule" "private_subnet_access" {
  name                                 = "${azurerm_postgresql_server.postgresserver.name}-private-subnet-access"
  resource_group_name                  = var.resource_group.name
  server_name                          = azurerm_postgresql_server.postgresserver.name
  subnet_id                            = var.private_subnet.id
  ignore_missing_vnet_service_endpoint = false

  depends_on = [azurerm_postgresql_server.postgresserver]
}

resource "azurerm_postgresql_virtual_network_rule" "public_subnet_access" {
  name                                 = "${azurerm_postgresql_server.postgresserver.name}-public-subnet-access"
  resource_group_name                  = var.resource_group.name
  server_name                          = azurerm_postgresql_server.postgresserver.name
  subnet_id                            = var.public_subnet.id
  ignore_missing_vnet_service_endpoint = false

  depends_on = [azurerm_postgresql_server.postgresserver]
}

# Needed to allow Paragon migrations that use `dblink` to run
resource "azurerm_postgresql_firewall_rule" "allow_dblink" {
  name                = "allow_dblink"
  resource_group_name = var.resource_group.name
  server_name         = azurerm_postgresql_server.postgresserver.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

