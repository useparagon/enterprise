output "resource_group" {
  value = azurerm_resource_group.main
}

output "virtual_network" {
  value = azurerm_virtual_network.main
}

output "public_subnet" {
  value = azurerm_subnet.public
}

output "private_subnet" {
  value = azurerm_subnet.private
}
