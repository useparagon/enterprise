resource "azurerm_subnet" "postgres" {
  name = "${var.workspace}-postgres-subnet"

  address_prefixes     = [cidrsubnet(tolist(var.virtual_network.address_space)[0], 4, 4)]
  resource_group_name  = var.resource_group.name
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
  virtual_network_name = var.virtual_network.name

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_network_security_group" "postgres" {
  name                = "${var.workspace}-postgres"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  security_rule {
    name                       = "allow-private-postgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    destination_port_range     = "5432"
    source_port_range          = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "postgres" {
  subnet_id                 = azurerm_subnet.postgres.id
  network_security_group_id = azurerm_network_security_group.postgres.id
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.workspace}.postgres.database.azure.com"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_subnet_network_security_group_association.postgres]
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.workspace}-postgres"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = var.resource_group.name
  virtual_network_id    = var.virtual_network.id
}
