output "network" {
  value = google_compute_network.paragon
}

output "service_networking_connection" {
  description = "Used so postgres (and other consumers) depend on it; connection is destroyed last (with network) after Cloud SQL and Memorystore are gone."
  value       = google_service_networking_connection.private_vpc_connection
}

output "public_subnet" {
  value = google_compute_subnetwork.public
}

output "private_subnet" {
  value = google_compute_subnetwork.private
}

output "nat_ip_address" {
  value = google_compute_address.nat_ip.address
}
