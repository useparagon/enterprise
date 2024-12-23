locals {
  cluster_name = "${var.workspace}-cluster"

  nodes = merge(
    var.k8s_spot_instance_percent < 100 ? {
      ondemand = {
        min_count = ceil((var.k8s_min_node_count - 1) * (1 - (var.k8s_spot_instance_percent / 100)))
        max_count = ceil((var.k8s_max_node_count - 1) * (1 - (var.k8s_spot_instance_percent / 100)))
        vm_size   = var.k8s_ondemand_node_instance_type
      }
    } : {},
    var.k8s_spot_instance_percent > 0 ? {
      spot = {
        min_count = floor((var.k8s_min_node_count - 1) * (var.k8s_spot_instance_percent / 100))
        max_count = ceil((var.k8s_max_node_count - 1) * (var.k8s_spot_instance_percent / 100))
        vm_size   = var.k8s_spot_node_instance_type
      }
    } : {}
  )
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = local.cluster_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  dns_prefix          = local.cluster_name
  kubernetes_version  = var.k8s_version
  node_resource_group = "${local.cluster_name}-nodes"
  sku_tier            = var.k8s_sku_tier

  # NOTE: The configuration for the cluster can't change at all
  # We're intentionally setting very low settings.
  # This way, we can instead reconfigure the node pools using `azurerm_kubernetes_cluster_node_pool` resource.
  default_node_pool {
    name       = "default"
    node_count = 1
    # intentionally setting cheapest usable node pool which costs ~ $30 / mo
    # while there are cheaper options, the minimum requirements for this are 2 cpu and 4gb memory
    # https://azureprice.net/
    vm_size              = "Standard_B2s"
    type                 = "VirtualMachineScaleSets"
    auto_scaling_enabled = false
    vnet_subnet_id       = var.private_subnet.id
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "172.0.0.10"
    service_cidr   = "172.0.0.0/16"
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [default_node_pool[0].upgrade_settings]
  }
}

# created as a separate resource so config can be updated
# if `default_node_pool` is updated in the `azurerm_kubernetes_cluster`,
# all terraform updates fail
resource "azurerm_kubernetes_cluster_node_pool" "pool" {
  for_each = local.nodes

  name                  = each.key
  auto_scaling_enabled  = true
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  max_count             = each.value.max_count
  min_count             = each.value.min_count
  orchestrator_version  = var.k8s_version
  os_sku                = "Ubuntu"
  os_type               = "Linux"
  priority              = "Regular"
  tags                  = merge(var.tags, { Name = each.key })
  vm_size               = each.value.vm_size
  vnet_subnet_id        = var.private_subnet.id

  node_labels = {
    "useparagon.com/capacityType" = each.key
  }
}
