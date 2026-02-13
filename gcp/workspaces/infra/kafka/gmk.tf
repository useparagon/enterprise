# Google Managed Service for Apache Kafka cluster (GMK).
# Authentication: SASL/OAUTHBEARER via ADC or Workload Identity (no username/password).
resource "google_managed_kafka_cluster" "kafka" {
  project    = var.gcp_project_id
  cluster_id = var.workspace
  location   = var.region

  capacity_config {
    vcpu_count   = var.gmk_vcpu_count
    memory_bytes = var.gmk_memory_bytes
  }

  broker_capacity_config {
    disk_size_gib = var.gmk_disk_size_gib
  }

  gcp_config {
    access_config {
      network_configs {
        # API expects projects/{project}/regions/{region}/subnetworks/{name}, not the full self_link URL.
        subnet = replace(var.private_subnet_uri, "https://www.googleapis.com/compute/v1/", "")
      }
    }
  }

  # Rebalance only when explicitly enabled (can add load during rebalance).
  dynamic "rebalance_config" {
    for_each = var.gmk_auto_rebalance ? [1] : []
    content {
      mode = "AUTO_REBALANCE_ON_SCALE_UP"
    }
  }
}
