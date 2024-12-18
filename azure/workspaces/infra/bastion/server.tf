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
  sku                 = "Standard_B2s"
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

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  upgrade_mode = "Automatic"

  tags = {
    Name = local.bastion_name
  }
}

# resource "azurerm_virtual_machine" "bastion" {
#   name                = "${var.app_name}-bastion"
#   resource_group_name = var.resource_group.name
#   location            = var.resource_group.location
#   vm_size             = "Standard_B1s"
#   availability_set_id = azurerm_availability_set.bastion.id
#   network_interface_ids = [
#     azurerm_network_interface.bastion.id,
#   ]
#   delete_data_disks_on_termination = true
#   delete_os_disk_on_termination    = true

#   os_profile {
#     computer_name  = "${var.app_name}-bastion"
#     admin_username = random_string.bastion_admin_username.result
#     admin_password = random_string.bastion_admin_password.result
#     # disable_password_authentication = false
#   }

#   storage_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "16.04-LTS"
#     # TODO: fix the version so it doesn't update on Terraform updates
#     version = "latest"
#   }

#   storage_os_disk {
#     name              = "${var.app_name}-bastion"
#     create_option     = "FromImage"
#     managed_disk_type = "Standard_LRS"
#     caching           = "ReadWrite"
#   }

#   os_profile_linux_config {
#     disable_password_authentication = false

#     ssh_keys {
#       path     = "/home/${random_string.bastion_admin_username.result}/.ssh/authorized_keys"
#       key_data = tls_private_key.bastion.public_key_openssh
#     }
#   }

#   connection {
#     type     = "ssh"
#     user     = random_string.bastion_admin_username.result
#     password = random_string.bastion_admin_password.result
#     host     = azurerm_public_ip.bastion.fqdn
#   }
# }

# #Install neccessary software dependencies
# resource "null_resource" "install" {
#   triggers = {
#     on_creation = azurerm_virtual_machine.bastion.id
#   }

#   connection {
#     type     = "ssh"
#     user     = random_string.bastion_admin_username.result
#     password = random_string.bastion_admin_password.result
#     host     = azurerm_public_ip.bastion.fqdn
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt-get -y update",
#       "sudo apt remove -y unattended-upgrades",
#       "sudo apt-get install -y redis-tools",
#       "sudo apt-get install -y docker.io",
#       "sudo -E curl -L https://github.com/docker/compose/releases/download/1.27.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose",
#       "sudo chmod +x /usr/local/bin/docker-compose",
#       "(sudo groupadd docker || true)",
#       "(sudo usermod -aG docker $USER || true)",
#       "sudo chmod 666 /var/run/docker.sock",
#       "sudo apt-get -y install postgresql postgresql-contrib"
#     ]
#   }

#   # install kubectl
#   provisioner "remote-exec" {
#     inline = [
#       "mkdir /home/${random_string.bastion_admin_username.result}/.kube/ ; sudo snap install --classic kubectl",
#     ]
#   }

#   provisioner "remote-exec" {
#     inline = [

#       # login to azure service principal
#       "echo \"Logging in to Azure Subscription\"",
#       "az login --service-principal -u ${var.client_id} -p ${var.client_secret} --tenant ${var.tenant_id}",
#       "az account set --subscription ${var.subscription_id}",

#       # install azure aks cli
#       "sudo az aks install-cli",

#       # install helm
#       "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -",
#       "sudo apt-get install -y apt-transport-https",
#       "echo \"deb https://baltocdn.com/helm/stable/debian/ all main\" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list",
#       "sudo apt-get update -y",
#       "sudo apt-get install -y helm",

#       "echo \"✅ Installed AzureCLI.\"",
#     ]
#   }

#   depends_on = [
#     azurerm_virtual_machine.bastion,
#     var.wait_for_cluster,
#   ]
# }

# #Run scripts
# resource "null_resource" "update" {
#   triggers = {
#     server                  = azurerm_virtual_machine.bastion.id
#     install                 = null_resource.install.id
#     deployment_cache_buster = var.deployment_cache_buster
#     kube_config             = jsonencode(data.azurerm_kubernetes_cluster.cluster.kube_config)
#   }

#   connection {
#     type     = "ssh"
#     user     = random_string.bastion_admin_username.result
#     host     = azurerm_public_ip.bastion.fqdn
#     password = random_string.bastion_admin_password.result
#   }

#   provisioner "file" {
#     content     = data.azurerm_kubernetes_cluster.cluster.kube_config_raw
#     destination = "/home/${random_string.bastion_admin_username.result}/.kube/config"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo \"⌛️ Updating kubectl config...\"",

#       "az aks get-credentials --overwrite-existing --resource-group ${var.resource_group.name} --name ${var.app_name}-aks",
#       "kubectl config set-context --current --namespace=paragon",

#       "echo \"✅ Updated kubectl config.\"",
#     ]
#   }

#   depends_on = [
#     azurerm_virtual_machine.bastion,
#     null_resource.install,
#     var.wait_for_cluster,
#   ]
# }
