data "google_client_config" "paragon" {}

data "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.region
}
