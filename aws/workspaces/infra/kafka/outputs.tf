output "cluster_arn" {
  description = "The ARN of the MSK cluster"
  value       = aws_msk_cluster.kafka.arn
}

output "cluster_id" {
  description = "The ID of the MSK cluster"
  value       = aws_msk_cluster.kafka.id
}

output "cluster_name" {
  description = "The name of the MSK cluster"
  value       = aws_msk_cluster.kafka.cluster_name
}

output "cluster_bootstrap_brokers" {
  description = "A comma separated list of one or more hostname:port pairs of kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}

output "cluster_bootstrap_brokers_tls" {
  description = "A comma separated list of one or more DNS names (or IPs) and TLS port pairs kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_tls
}

output "cluster_bootstrap_brokers_sasl_scram" {
  description = "A comma separated list of one or more DNS names (or IPs) and SASL SCRAM port pairs kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_sasl_scram
}

output "cluster_tls_enabled" {
  description = "Whether TLS is enabled for the MSK cluster"
  value       = true
}

output "zookeeper_connect_string" {
  description = "A comma separated list of one or more DNS names (or IPs) and SASL IAM port pairs kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.zookeeper_connect_string
}

output "zookeeper_connect_string_tls" {
  description = "A comma separated list of one or more DNS names (or IPs) and SASL IAM port pairs kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.zookeeper_connect_string_tls
}

output "kafka_credentials" {
  value = {
    username  = random_string.msk_username.result
    password  = random_password.msk_password.result
    mechanism = "scram-sha-512"
  }
}
