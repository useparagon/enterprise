resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_instance" "bastion" {
  name                      = local.bastion_name
  machine_type              = "e2-highmem-4"
  project                   = var.gcp_project_id
  allow_stopping_for_update = true
  tags                      = local.only_cloudflare_tunnel ? [] : ["allow-ssh"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 40
    }
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

  labels = {
    "name" = local.bastion_name
  }
}
