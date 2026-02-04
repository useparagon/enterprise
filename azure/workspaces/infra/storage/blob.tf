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

resource "azurerm_storage_account" "blob" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  account_kind                    = "BlockBlobStorage"
  account_replication_type        = "LRS"
  account_tier                    = "Premium"
  allow_nested_items_to_be_public = true
  tags                            = merge(var.tags, { Name = local.storage_account_name })
}

resource "azurerm_storage_container" "app" {
  name                  = "${var.workspace}-app"
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.blob.id
}

resource "azurerm_storage_container" "cdn" {
  name                  = "${var.workspace}-cdn"
  container_access_type = "container"
  storage_account_id    = azurerm_storage_account.blob.id
}

resource "azurerm_storage_container" "logs" {
  name                  = "${var.workspace}-logs"
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.blob.id
}

resource "azurerm_storage_container" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name                  = "${var.workspace}-managed-sync"
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.blob.id
}

resource "azurerm_storage_container" "auditlogs" {
  name                  = "${var.workspace}-auditlogs"
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.blob.id
}

resource "azurerm_storage_container_immutability_policy" "auditlogs" {
  count = var.auditlogs_lock_enabled ? 1 : 0

  storage_container_resource_manager_id = azurerm_storage_container.auditlogs.id
  immutability_period_in_days           = var.auditlogs_retention_days
}

resource "azurerm_storage_account_network_rules" "storage" {
  storage_account_id = azurerm_storage_account.blob.id

  bypass                     = ["Metrics"]
  default_action             = "Allow"
  ip_rules                   = []
  virtual_network_subnet_ids = var.virtual_network_subnet_ids
}
