output "msk_cluster_arn" {
  description = "The ARN of the MSK cluster"
  value       = aws_msk_cluster.kafka.arn
}

output "msk_cluster_id" {
  description = "The ID of the MSK cluster"
  value       = aws_msk_cluster.kafka.id
}

output "msk_cluster_name" {
  description = "The name of the MSK cluster"
  value       = aws_msk_cluster.kafka.cluster_name
}

output "msk_cluster_bootstrap_brokers" {
  description = "A comma separated list of one or more hostname:port pairs of kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}

output "msk_cluster_bootstrap_brokers_tls" {
  description = "A comma separated list of one or more DNS names (or IPs) and TLS port pairs kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_tls
}

output "msk_cluster_bootstrap_brokers_sasl_iam" {
  description = "A comma separated list of one or more DNS names (or IPs) and SASL IAM port pairs kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
}
