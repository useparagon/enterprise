# Unified Hoop connections - all connection types in a single resource
resource "hoop_connection" "all_connections" {
  for_each = var.hoop_enabled ? toset(keys(local.all_connections)) : []

  name     = local.all_connections[each.value].name
  type     = local.all_connections[each.value].type
  agent_id = var.hoop_agent_id

  access_mode_runbooks = local.all_connections[each.value].access_mode_runbooks
  access_mode_exec     = local.all_connections[each.value].access_mode_exec
  access_mode_connect  = local.all_connections[each.value].access_mode_connect
  access_schema        = local.all_connections[each.value].access_schema

  subtype         = local.all_connections[each.value].subtype
  command         = local.all_connections[each.value].command
  guardrail_rules = try(local.all_connections[each.value].guardrail_rules, null) != null && length(coalesce(try(local.all_connections[each.value].guardrail_rules, null), [])) > 0 ? local.all_connections[each.value].guardrail_rules : null
  reviewers       = try(local.all_connections[each.value].reviewers, null) != null && length(coalesce(try(local.all_connections[each.value].reviewers, null), [])) > 0 ? local.all_connections[each.value].reviewers : null

  secrets = local.all_connections[each.value].secrets
  tags    = local.all_connections[each.value].tags

  depends_on = [
    data.kubernetes_secret_v1.hoop_cluster_admin_token
  ]
}

# Provider normalizes Postgres command; ignore to avoid perpetual drift.
resource "hoop_connection" "postgres_connections" {
  for_each = var.hoop_enabled ? toset(keys(local.postgres_connections)) : []

  name     = local.postgres_connections[each.value].name
  type     = local.postgres_connections[each.value].type
  agent_id = var.hoop_agent_id

  access_mode_runbooks = local.postgres_connections[each.value].access_mode_runbooks
  access_mode_exec     = local.postgres_connections[each.value].access_mode_exec
  access_mode_connect  = local.postgres_connections[each.value].access_mode_connect
  access_schema        = local.postgres_connections[each.value].access_schema

  subtype         = local.postgres_connections[each.value].subtype
  command         = local.postgres_connections[each.value].command
  guardrail_rules = try(local.postgres_connections[each.value].guardrail_rules, null) != null && length(coalesce(try(local.postgres_connections[each.value].guardrail_rules, null), [])) > 0 ? local.postgres_connections[each.value].guardrail_rules : null
  reviewers       = try(local.postgres_connections[each.value].reviewers, null) != null && length(coalesce(try(local.postgres_connections[each.value].reviewers, null), [])) > 0 ? local.postgres_connections[each.value].reviewers : null

  secrets = local.postgres_connections[each.value].secrets
  tags    = local.postgres_connections[each.value].tags

  lifecycle {
    ignore_changes = [command]
  }

  depends_on = [
    data.kubernetes_secret_v1.hoop_cluster_admin_token
  ]
}

# Access control plugin for custom connections (uses explicit access_control_groups or default: restricted oncall/admin; + all when not customer_facing)
resource "hoop_plugin_connection" "custom_connections_access_control" {
  for_each = var.hoop_enabled ? local.custom_connections_access_control_groups : {}

  plugin_name   = "access_control"
  connection_id = hoop_connection.all_connections[each.key].id
  config        = each.value
}

resource "hoop_plugin_connection" "default_connections_access_control" {
  for_each = var.hoop_enabled ? {
    for conn_name, groups in local.access_control_groups :
    conn_name => groups
    if !startswith(conn_name, "custom-")
  } : {}

  plugin_name   = "access_control"
  connection_id = hoop_connection.all_connections[each.key].id
  config        = each.value
}

resource "hoop_plugin_connection" "postgres_connections_access_control" {
  for_each = var.hoop_enabled ? local.postgres_access_control_groups : {}

  plugin_name   = "access_control"
  connection_id = hoop_connection.postgres_connections[each.key].id
  config        = each.value
}
