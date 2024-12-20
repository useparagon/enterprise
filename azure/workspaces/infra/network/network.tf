resource "azurerm_resource_group" "main" {
  name = "${var.workspace}-resources"

  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name = "${var.workspace}-network"

  address_space       = [var.vpc_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_subnet" "public" {
  name = "${var.workspace}-public-subnet"

  address_prefixes     = [cidrsubnet(var.vpc_cidr, 4, 0)]
  resource_group_name  = azurerm_resource_group.main.name
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.main.name
}

resource "azurerm_subnet" "private" {
  name = "${var.workspace}-private-subnet"

  address_prefixes     = [cidrsubnet(var.vpc_cidr, 4, 2)]
  resource_group_name  = azurerm_resource_group.main.name
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.main.name
}
