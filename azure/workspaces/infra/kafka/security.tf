# Private Endpoint for Event Hubs Namespace
resource "azurerm_private_endpoint" "kafka" {
  name                = "${var.workspace}-kafka-pe"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  subnet_id           = var.private_subnet.id

  private_service_connection {
    name                           = "${var.workspace}-kafka-connection"
    private_connection_resource_id = azurerm_eventhub_namespace.kafka.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, { Name = "${var.workspace}-kafka-pe" })
}

# Private DNS Zone for Event Hubs
resource "azurerm_private_dns_zone" "kafka" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group.name
  tags                = merge(var.tags, { Name = "${var.workspace}-kafka-dns" })
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "kafka" {
  name                  = "${var.workspace}-kafka-dns-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.kafka.name
  virtual_network_id    = var.virtual_network.id
  tags                  = merge(var.tags, { Name = "${var.workspace}-kafka-dns-link" })
}

# DNS A Record for Event Hubs Namespace
resource "azurerm_private_dns_a_record" "kafka" {
  name                = azurerm_eventhub_namespace.kafka.name
  zone_name           = azurerm_private_dns_zone.kafka.name
  resource_group_name = var.resource_group.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.kafka.private_service_connection[0].private_ip_address]

  depends_on = [azurerm_private_endpoint.kafka]
}



