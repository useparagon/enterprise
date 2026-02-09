output "load_balancer" {
  value = google_compute_global_address.loadbalancer.address
}

output "openobserve_email" {
  value = local.openobserve_email
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}

output "namespace_paragon" {
  value = kubernetes_namespace_v1.paragon
}
