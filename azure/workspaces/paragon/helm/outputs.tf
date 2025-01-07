output "load_balancer" {
  value = azurerm_public_ip.ingress.fqdn
}

output "openobserve_email" {
  value = local.openobserve_email
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}
