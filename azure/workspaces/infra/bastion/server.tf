locals {
  bastion_name           = "${var.workspace}-bastion"
  only_cloudflare_tunnel = var.cloudflare_tunnel_enabled
  # Normalize k8s_version to major.minor (e.g. 1.33.5 -> 1.33, 1.33 -> 1.33)
  k8s_version_major_minor = join(".", slice(split(".", var.k8s_version), 0, 2))
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# User-assigned identity so role assignments can use a top-level principal_id. Referencing
# azurerm_linux_virtual_machine_scale_set.*.identity[0].principal_id breaks validation in
# some root-module graphs (nested computed; see hashicorp/terraform-provider-azurerm#21545).
resource "azurerm_user_assigned_identity" "bastion" {
  name                = "${local.bastion_name}-uai"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  tags = var.tags
}

resource "azurerm_linux_virtual_machine_scale_set" "bastion" {
  name                = local.bastion_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  sku                 = var.bastion_vm_size
  instances           = 1

  admin_username = "ubuntu"

  network_interface {
    name    = "${local.bastion_name}-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      subnet_id = var.private_subnet.id
      primary   = true
    }
  }

  # Bastion runtime auth to Azure/AKS is always this identity (not the Terraform principal).
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.bastion.id]
  }

  custom_data = base64encode(templatefile("${path.module}/../templates/bastion/bastion-startup.tpl.sh", {
    account_id                 = var.cloudflare_tunnel_account_id,
    cluster_name               = var.cluster_name,
    cluster_version            = local.k8s_version_major_minor,
    managed_identity_client_id = azurerm_user_assigned_identity.bastion.client_id,
    resource_group             = var.resource_group.name,
    subscription_id            = var.azure_subscription_id,
    tunnel_id                  = local.tunnel_id,
    tunnel_name                = local.tunnel_domain,
    tunnel_secret              = local.tunnel_secret,
  }))

  admin_ssh_key {
    username   = "ubuntu"
    public_key = tls_private_key.bastion.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 100
    max_unhealthy_instance_percent          = 100
    max_unhealthy_upgraded_instance_percent = 100
    pause_time_between_batches              = "PT0S"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  upgrade_mode = "Automatic"

  tags = merge(var.tags, { Name = local.bastion_name })
}

# Allow the bastion VMSS managed identity to fetch kubeconfig and use kubectl against AKS.
resource "azurerm_role_assignment" "bastion_aks_cluster_admin" {
  scope                = var.cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = azurerm_user_assigned_identity.bastion.principal_id
}
