output "namespace_name" {
  description = "The name of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.kafka.name
}

output "bootstrap_servers" {
  description = "The Kafka bootstrap servers connection string (for Kafka protocol)"
  value       = "${azurerm_eventhub_namespace.kafka.name}.servicebus.windows.net:9093"
}

output "bootstrap_servers_private" {
  description = "The private DNS name for Kafka bootstrap servers"
  value       = "${azurerm_eventhub_namespace.kafka.name}.privatelink.servicebus.windows.net:9093"
}

output "kafka_credentials" {
  description = "Kafka credentials (Event Hubs uses SASL PLAIN authentication with connection string)"
  value = {
    username  = "$ConnectionString"
    password  = azurerm_eventhub_namespace_authorization_rule.kafka.primary_connection_string
    mechanism = "PLAIN" # Event Hubs uses SASL PLAIN authentication
  }
  sensitive = true
}

output "tls_enabled" {
  description = "Whether TLS is enabled for the Event Hubs namespace"
  value       = true
}

