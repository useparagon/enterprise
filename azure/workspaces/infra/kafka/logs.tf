# Diagnostic settings for Event Hubs Namespace
resource "azurerm_monitor_diagnostic_setting" "kafka" {
  name                       = "${var.workspace}-kafka-logs"
  target_resource_id         = azurerm_eventhub_namespace.kafka.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.kafka.id

  enabled_log {
    category_group = "allLogs"
  }

  lifecycle {
    ignore_changes = [metric]
  }
}

# Log Analytics Workspace for Event Hubs diagnostics
resource "azurerm_log_analytics_workspace" "kafka" {
  name                = "${var.workspace}-kafka-logs"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.tags, { Name = "${var.workspace}-kafka-logs" })
}

