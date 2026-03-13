output "network" {
  value = google_compute_network.paragon
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
