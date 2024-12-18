# output "bastion" {
#   description = "Bastion connection configuration."
#   value = {
#     private_key = tls_private_key.bastion.private_key_pem
#     public_key  = tls_private_key.bastion.public_key_openssh
#     # host_name   = azurerm_virtual_machine.bastion.name
#     # public_ip   = azurerm_public_ip.bastion.ip_address
#     # private_ip  = azurerm_network_interface.bastion.private_ip_address
#   }
#   sensitive = true
# }

output "connection" {
  value = {
    bastion_dns = local.tunnel_domain
    private_key = tls_private_key.bastion.private_key_pem
  }
  sensitive = true
}
