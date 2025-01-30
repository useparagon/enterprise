provider "google" {
  credentials    = local.gcp_creds
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "google-beta" {
  credentials    = local.gcp_creds
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}
