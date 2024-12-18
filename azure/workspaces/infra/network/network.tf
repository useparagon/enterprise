resource "azurerm_resource_group" "main" {
  name     = "${var.workspace}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.workspace}-network"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vpc_cidr]
}

resource "azurerm_subnet" "private" {
  name                 = "${var.workspace}-private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 2, 0)]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
}

resource "azurerm_subnet" "public" {
  name                 = "${var.workspace}-public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 2, 1)]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
}
