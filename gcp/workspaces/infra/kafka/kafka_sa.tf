# Dedicated service account for Kafka (Managed Sync). Used for OAUTHBEARER (Workload Identity) or PLAIN (key file).

# account_id must be 6–30 chars (GCP). Workspace can exceed that, so use a short suffix.
resource "google_service_account" "kafka_client" {
  project      = var.gcp_project_id
  account_id   = "kafka-${substr(md5(var.workspace), 0, 8)}-client"
  display_name = "Kafka client for Managed Sync (${var.workspace})"
}

# Grant the SA permission to connect to Managed Kafka (data plane).
resource "google_project_iam_member" "kafka_client" {
  project = var.gcp_project_id
  role    = "roles/managedkafka.client"
  member  = "serviceAccount:${google_service_account.kafka_client.email}"
}

# Create a key for the Kafka SA when using SASL/PLAIN. Credentials are exposed via outputs (cluster_password) for paragon/Kafka.
resource "google_service_account_key" "kafka_client" {
  count = var.gmk_sasl_mechanism == "plain" ? 1 : 0

  service_account_id = google_service_account.kafka_client.name
}

