resource "random_string" "kafka_username" {
  length  = 16
  special = false
}

resource "random_password" "kafka_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Event Hubs Namespace with Kafka support
resource "azurerm_eventhub_namespace" "kafka" {
  name                = "${replace(var.workspace, "-", "")}kafka${substr(sha256(var.workspace), 0, 8)}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  sku                      = var.eventhub_namespace_sku
  capacity                 = var.eventhub_capacity
  auto_inflate_enabled     = var.eventhub_auto_inflate_enabled
  maximum_throughput_units = var.eventhub_auto_inflate_enabled ? var.eventhub_maximum_throughput_units : null

  # Network configuration - start with private endpoint only
  # Note: Kafka protocol is automatically enabled for Standard and Premium SKUs
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"

  # Encryption
  local_authentication_enabled = true
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, { Name = "${var.workspace}-kafka" })
}

# Event Hub (topic) for Kafka
resource "azurerm_eventhub" "kafka" {
  name              = var.workspace
  namespace_id      = azurerm_eventhub_namespace.kafka.id
  partition_count   = 3
  message_retention = 7
}

# Authorization rule for SAS authentication (used by Kafka clients)
resource "azurerm_eventhub_namespace_authorization_rule" "kafka" {
  name                = "${var.workspace}-kafka-auth"
  namespace_name      = azurerm_eventhub_namespace.kafka.name
  resource_group_name = var.resource_group.name

  listen = true
  send   = true
  manage = false
}

