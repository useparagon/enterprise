resource "random_string" "storage_hash" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  # storage accounts must be globally unique and only up to 24 lower case alphanumeric characters
  storage_account_name = "${substr(replace(var.workspace, "/[^a-z0-9]/", ""), 0, 16)}${random_string.storage_hash.result}"
}

resource "azurerm_storage_account" "redis" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  account_replication_type         = "GRS"
  account_tier                     = "Standard"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  tags                             = merge(var.tags, { Name = local.storage_account_name })
}

resource "azurerm_redis_cache" "redis" {
  name                = "${var.workspace}-cache"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  capacity                      = var.redis_capacity
  family                        = var.redis_sku_name == "Premium" ? "P" : "C"
  minimum_tls_version           = "1.2"
  non_ssl_port_enabled          = true # TODO restrict to just SSL
  public_network_access_enabled = false
  redis_version                 = "6"
  sku_name                      = var.redis_sku_name
  subnet_id                     = var.redis_subnet.id
  tags                          = merge(var.tags, { Name = "${var.workspace}-cache" })

  redis_configuration {
    authentication_enabled        = false
    rdb_backup_enabled            = true
    rdb_backup_frequency          = 60
    rdb_backup_max_snapshot_count = 1
    rdb_storage_connection_string = azurerm_storage_account.redis.primary_blob_connection_string
  }

  lifecycle {
    ignore_changes = [redis_configuration.0.rdb_storage_connection_string]
  }
}
