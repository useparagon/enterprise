output "load_balancer" {
  value = var.ingress_scheme == "internal" ? "" : azurerm_public_ip.ingress[0].fqdn
}

output "openobserve_email" {
  value = local.openobserve_email
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}
