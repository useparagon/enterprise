resource "random_string" "storage_hash" {
  length  = 12
  special = false
  number  = true
  lower   = true
  upper   = false
}

resource "azurerm_storage_account" "redis" {
  name                = replace("paragon-redis-${random_string.storage_hash.result}", "/\\W|_|\\s/", "")
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  account_tier                     = "Standard"
  account_replication_type         = "GRS"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
}

resource "azurerm_redis_cache" "redis" {
  name                          = "${var.app_name}-cache"
  location                      = var.resource_group.location
  resource_group_name           = var.resource_group.name
  capacity                      = var.redis_capacity
  family                        = "P"
  sku_name                      = "Premium"
  enable_non_ssl_port           = true
  redis_version                 = "6"
  public_network_access_enabled = true
  subnet_id                     = azurerm_subnet.redis.id
  minimum_tls_version           = "1.2"

  redis_configuration {
    enable_authentication         = false
    rdb_backup_enabled            = true
    rdb_backup_frequency          = 60
    rdb_backup_max_snapshot_count = 1
    rdb_storage_connection_string = azurerm_storage_account.redis.primary_blob_connection_string
  }

  lifecycle {
    ignore_changes = [redis_configuration.0.rdb_storage_connection_string]
  }
}
