output "kubernetes" {
  value = {
    name                   = module.gke.name
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.paragon.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
  sensitive = true
}