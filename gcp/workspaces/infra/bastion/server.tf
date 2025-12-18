resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate suffix based on startup script content
locals {
  startup_script_hash = substr(sha256(file("${path.module}/../templates/bastion/bastion-startup.tpl.sh")), 0, 6)
}


# Instance template for the bastion
resource "google_compute_instance_template" "bastion_v2" {
  name         = "${local.bastion_name}-${local.startup_script_hash}"
  description  = "Template for bastion host with auto-recovery"
  machine_type = "e2-highmem-4"
  project      = var.gcp_project_id

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 40
  }

  network_interface {
    network    = var.network.self_link
    subnetwork = var.private_subnet.name

    dynamic "access_config" {
      for_each = local.only_cloudflare_tunnel ? [] : [1]
      content {
        nat_ip = google_compute_address.bastion[0].address
      }
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.bastion.public_key_openssh}"

    startup-script = templatefile("${path.module}/../templates/bastion/bastion-startup.tpl.sh", {
      account_id      = var.cloudflare_tunnel_account_id,
      admin_user      = "ubuntu",
      cluster_name    = var.cluster_name,
      cluster_version = var.k8s_version,
      project         = var.gcp_project_id,
      region          = var.region,
      tunnel_id       = local.tunnel_id,
      tunnel_name     = local.tunnel_domain,
      tunnel_secret   = local.tunnel_secret,
    })
  }

  service_account {
    email = google_service_account.bastion.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  tags = local.only_cloudflare_tunnel ? [] : ["allow-ssh"]

  labels = {
    "name" = local.bastion_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Managed instance group for bastion (auto-healing disabled due to no exposed ports)
resource "google_compute_instance_group_manager" "bastion" {
  name               = "${local.bastion_name}-mig"
  description        = "Managed instance group for bastion (auto-healing disabled - uses Cloudflare tunnel)"
  base_instance_name = local.bastion_name
  project            = var.gcp_project_id
  zone               = var.region_zone

  version {
    instance_template = google_compute_instance_template.bastion_v2.id
  }

  # Update policy for rolling updates - allows template changes
  update_policy {
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
    minimal_action        = "REPLACE"
    replacement_method    = "SUBSTITUTE"
    type                  = "PROACTIVE"
  }

  # Ensure at least 1 instance is always running
  target_size = 1
}
