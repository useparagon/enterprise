# <= v2.9.4 -> v2.10.0
# moved azure nodes so they can be conditionally created
moved {
  from = azurerm_kubernetes_cluster_node_pool.nodes
  to   = azurerm_kubernetes_cluster_node_pool.ondemand[0]
}
