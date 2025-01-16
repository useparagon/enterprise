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
  for_each = local.redis_instances

  name                = "${var.workspace}-${each.key}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  capacity                      = each.value.capacity
  family                        = each.value.sku == "Premium" ? "P" : "C"
  minimum_tls_version           = "1.2"
  non_ssl_port_enabled          = !var.redis_ssl_only
  public_network_access_enabled = false
  redis_version                 = "6"
  sku_name                      = each.value.sku
  tags                          = merge(var.tags, { Name = "${var.workspace}-${each.key}" })

  # azure restricts many of the features to only premium skus
  replicas_per_primary = each.value.cluster && each.value.sku == "Premium" ? 1 : null
  shard_count          = each.value.cluster && each.value.sku == "Premium" ? 2 : null
  subnet_id            = each.value.sku == "Premium" ? var.redis_subnet.id : null

  dynamic "redis_configuration" {
    for_each = each.value.sku == "Premium" ? [1] : []
    content {
      authentication_enabled        = false
      rdb_backup_enabled            = true
      rdb_backup_frequency          = 60
      rdb_backup_max_snapshot_count = 1
      rdb_storage_connection_string = azurerm_storage_account.redis.primary_blob_connection_string
    }
  }

  lifecycle {
    ignore_changes = [redis_configuration.0.rdb_storage_connection_string]
  }
}
