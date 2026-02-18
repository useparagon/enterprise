# Outputs match the contract expected by paragon (same shape as AWS kafka output).
# Supports both: OAUTHBEARER (bind cluster_service_account_email via Workload Identity) or SASL/PLAIN (key JSON at cluster_password_file_path).

output "cluster_id" {
  description = "ID of the Managed Kafka cluster."
  value       = google_managed_kafka_cluster.kafka.cluster_id
}

output "cluster_name" {
  description = "Full resource name of the cluster."
  value       = google_managed_kafka_cluster.kafka.name
}

# Bootstrap: hostname from GMK API (gcloud managed-kafka clusters describe --format=value(bootstrapAddress)).
# Format: bootstrap.<cluster_id>.<region>.managedkafka.<project_id>.cloud.goog:9092 (not <id>-bootstrap.<region>.managedkafka.goog).
output "cluster_bootstrap_brokers" {
  description = "Bootstrap broker address for Kafka clients (host:port). Required for KafkaJS."
  value       = "bootstrap.${google_managed_kafka_cluster.kafka.cluster_id}.${google_managed_kafka_cluster.kafka.location}.managedkafka.${var.gcp_project_id}.cloud.goog:9092"
}

output "cluster_service_account_email" {
  description = "Dedicated Kafka client SA. OAUTHBEARER: bind via Workload Identity. PLAIN: use as SASL username."
  value       = google_service_account.kafka_client.email
}

output "cluster_username" {
  description = "SASL username: SA email when mechanism is plain, null when oauthbearer."
  value       = var.gmk_sasl_mechanism == "plain" ? google_service_account.kafka_client.email : null
}

output "cluster_password" {
  description = "SASL/PLAIN: JSON key content (created by module). Use as MANAGED_SYNC_KAFKA_SASL_PASSWORD or base64(key). Null when oauthbearer."
  value       = var.gmk_sasl_mechanism == "plain" ? base64decode(google_service_account_key.kafka_client[0].private_key) : null
  sensitive   = true
}

output "cluster_password_file_path" {
  description = "SASL/PLAIN: null when key is created by module (use cluster_password). Set gmk_sasl_plain_key_file_path only if you provide your own key file. Null when oauthbearer."
  value       = null
}

output "cluster_mechanism" {
  description = "SASL mechanism: oauthbearer or plain."
  value       = var.gmk_sasl_mechanism
}

output "cluster_tls_enabled" {
  description = "TLS is always enabled for the Managed Kafka data plane."
  value       = true
}
