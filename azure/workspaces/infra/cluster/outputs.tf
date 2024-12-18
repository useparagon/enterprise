output "kubernetes" {
  value = {
    host                   = "${data.azurerm_kubernetes_cluster.cluster.kube_config.0.host}"
    client_certificate     = "${data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate}"
    client_key             = "${data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key}"
    cluster_ca_certificate = "${data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate}"
    node_resource_group    = azurerm_kubernetes_cluster.paragon.node_resource_group
    kube_config            = "${data.azurerm_kubernetes_cluster.cluster.kube_config_raw}"
  }
  sensitive = true
}

output "wait_for_cluster" {
  description = "Variable that can be referenced to ensure cluster is initialized."
  value       = azurerm_kubernetes_cluster.paragon.fqdn
}

output "wait_for_cluster_ondemand_nodes" {
  description = "Variable that can be referenced to ensure on demand cluster nodes are available."
  value       = var.k8_spot_instance_percent < 100 ? azurerm_kubernetes_cluster_node_pool.ondemand[0].node_public_ip_prefix_id : azurerm_kubernetes_cluster_node_pool.spot[0].node_public_ip_prefix_id
}

output "wait_for_cluster_spot_nodes" {
  description = "Variable that can be referenced to ensure spot cluster nodes are available."
  value       = var.k8_spot_instance_percent > 0 ? azurerm_kubernetes_cluster_node_pool.spot[0].node_public_ip_prefix_id : azurerm_kubernetes_cluster_node_pool.ondemand[0].node_public_ip_prefix_id
}
