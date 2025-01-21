output "connection" {
  value = {
    bastion_dns = local.tunnel_domain
    private_key = tls_private_key.bastion.private_key_pem
  }
  sensitive = true
}
