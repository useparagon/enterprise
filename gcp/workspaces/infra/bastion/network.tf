resource "google_compute_address" "bastion" {
  count = local.only_cloudflare_tunnel ? 0 : 1

  name    = "${local.bastion_name}-public-ip"
  project = var.gcp_project_id
  region  = var.region
}

resource "google_compute_firewall" "ssh" {
  count = local.only_cloudflare_tunnel ? 0 : 1

  name          = "${local.bastion_name}-ssh"
  network       = var.network.self_link
  project       = var.gcp_project_id
  source_tags   = ["allow-ssh"]
  target_tags   = ["allow-ssh"]
  source_ranges = var.ssh_whitelist

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# IAP TCP forwarding (GCP equivalent to AWS Session Manager). Connect via gcloud from anywhere;
# no need to open SSH to the internet. Traffic goes over HTTPS to Google, then to the bastion.
# Requires: gcloud auth + IAM role roles/iap.tunnelResourceAccessor on the user.
resource "google_compute_firewall" "iap_ssh" {
  count = var.enable_iap ? 1 : 0

  name          = "${local.bastion_name}-iap-ssh"
  network       = var.network.self_link
  project       = var.gcp_project_id
  source_ranges = ["35.235.240.0/20"] # IAP forwarding IP range
  target_tags   = ["allow-iap"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
