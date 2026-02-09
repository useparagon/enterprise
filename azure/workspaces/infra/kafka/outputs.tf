output "namespace_name" {
  description = "The name of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.kafka.name
}

output "namespace_id" {
  description = "The ID of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.kafka.id
}

output "eventhub_name" {
  description = "The name of the Event Hub"
  value       = azurerm_eventhub.kafka.name
}

output "bootstrap_servers" {
  description = "The Kafka bootstrap servers connection string (for Kafka protocol)"
  value       = "${azurerm_eventhub_namespace.kafka.name}.servicebus.windows.net:9093"
}

output "bootstrap_servers_private" {
  description = "The private DNS name for Kafka bootstrap servers"
  value       = "${azurerm_eventhub_namespace.kafka.name}.privatelink.servicebus.windows.net:9093"
}

output "connection_string" {
  description = "The connection string for the Event Hubs namespace (SAS)"
  value       = azurerm_eventhub_namespace_authorization_rule.kafka.primary_connection_string
  sensitive   = true
}

output "primary_key" {
  description = "The primary key for the authorization rule"
  value       = azurerm_eventhub_namespace_authorization_rule.kafka.primary_key
  sensitive   = true
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

