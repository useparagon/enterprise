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

# Private service connection used by Cloud SQL and Memorystore. Lives in network so it is destroyed
# after postgres and redis (GCP fails to delete the connection while producers still use it).
resource "google_compute_global_address" "private_service_connect" {
  name          = "${var.workspace}-global-psconnect-ip"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = google_compute_network.paragon.id
  prefix_length = 16
  project       = var.gcp_project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.paragon.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connect.name]
}

# Delay before destroying the connection so GCP has time to release it after Cloud SQL/Memorystore are gone.
# Destroy order: this resource is destroyed first (runs sleep), then the connection can be removed.
resource "null_resource" "service_connection_teardown_delay" {
  depends_on = [google_service_networking_connection.private_vpc_connection]

  triggers = {
    connection_id = google_service_networking_connection.private_vpc_connection.id
  }

  lifecycle {
    create_before_destroy = true
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sleep 90"
  }
}
