resource "azurerm_kubernetes_cluster" "paragon" {
  name                = "${var.app_name}-aks"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  dns_prefix          = "${var.app_name}-aks"
  node_resource_group = "${var.app_name}-aks-node"
  kubernetes_version  = var.k8_version
  sku_tier            = "Paid"

  # NOTE: The configuration for the cluster can't change at all
  # We're intentionally setting very low settings.
  # This way, we can instead reconfigure the node pools using `azurerm_kubernetes_cluster_node_pool` resource.
  default_node_pool {
    name       = "default"
    node_count = 1
    # intentionally setting cheapest usable node pool which costs ~ $30 / mo
    # while there are cheaper options, the minimum requirements for this are 2 cpu and 4gb memory
    # https://azureprice.net/
    vm_size             = "Standard_B2s"
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = false
    vnet_subnet_id      = var.private_subnet.id
  }

  network_profile {
    service_cidr       = "172.0.0.0/16"
    network_plugin     = "azure"
    dns_service_ip     = "172.0.0.10"
    docker_bridge_cidr = "192.0.0.0/16"
  }

  identity {
    type = "SystemAssigned"
  }
}

# created as a separate resource so config can be updated
# if `default_node_pool` is updated in the `azurerm_kubernetes_cluster`,
# all terraform updates fail
resource "azurerm_kubernetes_cluster_node_pool" "ondemand" {
  count                 = var.k8_spot_instance_percent < 100 ? 1 : 0
  name                  = "ondemand"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.paragon.id
  vm_size               = var.k8_ondemand_node_instance_type
  os_type               = "Linux"
  os_sku                = "Ubuntu"
  priority              = "Regular"
  orchestrator_version  = var.k8_version
  vnet_subnet_id        = var.private_subnet.id

  # subtracting one from `k8_min_node_count` because default node
  # node_count          = ceil(var.k8_min_node_count * (1 - (var.k8_spot_instance_percent / 100)))
  min_count           = ceil((var.k8_min_node_count - 1) * (1 - (var.k8_spot_instance_percent / 100)))
  max_count           = ceil((var.k8_max_node_count - 1) * (1 - (var.k8_spot_instance_percent / 100)))
  enable_auto_scaling = true

  node_labels = {
    "useparagon.com/capacityType" = "ondemand"
  }
}


# created as a separate resource so config can be updated
# if `default_node_pool` is updated in the `azurerm_kubernetes_cluster`,
# all terraform updates fail
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                 = var.k8_spot_instance_percent > 0 ? 1 : 0
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.paragon.id
  vm_size               = var.k8_spot_node_instance_type
  os_type               = "Linux"
  os_sku                = "Ubuntu"
  priority              = "Spot"
  orchestrator_version  = var.k8_version
  vnet_subnet_id        = var.private_subnet.id

  # subtracting one from `k8_min_node_count` because default node
  # node_count          = ceil(var.k8_min_node_count * (var.k8_spot_instance_percent / 100))
  min_count           = floor((var.k8_min_node_count - 1) * (var.k8_spot_instance_percent / 100))
  max_count           = ceil((var.k8_max_node_count - 1) * (var.k8_spot_instance_percent / 100))
  enable_auto_scaling = true

  node_labels = {
    "useparagon.com/capacityType" = "spot"
  }
}
