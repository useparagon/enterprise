locals {
  bastion_name           = "${var.workspace}-bastion"
  only_cloudflare_tunnel = var.cloudflare_tunnel_enabled
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
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

  custom_data = base64encode(templatefile("${path.module}/../templates/bastion/bastion-startup.tpl.sh", {
    account_id      = var.cloudflare_tunnel_account_id,
    client_id       = var.azure_client_id,
    client_secret   = var.azure_client_secret,
    cluster_name    = var.cluster_name,
    cluster_version = var.k8s_version,
    resource_group  = var.resource_group.name
    subscription_id = var.azure_subscription_id,
    tenant_id       = var.azure_tenant_id,
    tunnel_id       = local.tunnel_id,
    tunnel_name     = local.tunnel_domain,
    tunnel_secret   = local.tunnel_secret,
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
