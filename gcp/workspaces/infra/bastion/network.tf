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
