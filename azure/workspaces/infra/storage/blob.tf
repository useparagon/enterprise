resource "random_string" "storage_hash" {
  length  = 10
  special = false
  number  = true
  lower   = true
  upper   = false
}

resource "azurerm_storage_account" "blob" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  account_tier                     = "Premium"
  account_kind                     = "BlockBlobStorage"
  account_replication_type         = "LRS"
  cross_tenant_replication_enabled = false
  enable_https_traffic_only        = true
  allow_nested_items_to_be_public  = true
}

resource "azurerm_storage_container" "app" {
  name                  = local.private_container_name
  storage_account_name  = azurerm_storage_account.blob.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "cdn" {
  name                  = local.public_container_name
  storage_account_name  = azurerm_storage_account.blob.name
  container_access_type = "container"
}

resource "azurerm_storage_account_network_rules" "storage" {
  storage_account_id = azurerm_storage_account.blob.id

  default_action             = "Allow"
  ip_rules                   = []
  virtual_network_subnet_ids = [var.public_subnet.id, var.private_subnet.id]
  bypass                     = ["Metrics"]
}

resource "random_string" "minio_microservice_user" {
  length  = 10
  special = false
  number  = true
  lower   = true
  upper   = false
}

resource "random_string" "minio_microservice_pass" {
  length  = 10
  special = false
  number  = true
  lower   = true
  upper   = false
}
