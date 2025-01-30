resource "google_compute_network" "paragon" {
  name                    = "${var.workspace}-network"
  auto_create_subnetworks = "false"
  project                 = var.gcp_project_id
}

resource "google_compute_subnetwork" "public" {
  name          = "${var.workspace}-public-subnet"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, var.vpc_cidr_newbits, 0)
  network       = google_compute_network.paragon.id
  project       = var.gcp_project_id
  region        = var.region
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.workspace}-private-subnet"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, var.vpc_cidr_newbits, 1)
  network       = google_compute_network.paragon.id
  project       = var.gcp_project_id
  region        = var.region

  secondary_ip_range {
    range_name    = "ip-pods-secondary-range"
    ip_cidr_range = var.pod_cidr
  }

  secondary_ip_range {
    range_name    = "ip-services-secondary-range"
    ip_cidr_range = var.service_cidr
  }
}

resource "google_compute_address" "nat_ip" {
  name    = "${var.workspace}-nat-ip"
  project = var.gcp_project_id
  region  = var.region
}

resource "google_compute_router" "nat_router" {
  name    = "${var.workspace}-nat-router"
  network = google_compute_network.paragon.name
}

resource "google_compute_router_nat" "nat_gateway" {
  name                               = "${var.workspace}-nat-gateway"
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  project                            = var.gcp_project_id
  router                             = google_compute_router.nat_router.name
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
