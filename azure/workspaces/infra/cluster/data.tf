data "azurerm_kubernetes_cluster" "cluster" {
  name                = azurerm_kubernetes_cluster.paragon.name
  resource_group_name = var.resource_group.name
  depends_on = [
    azurerm_kubernetes_cluster.paragon
  ]
}
