locals {
  # Detect cloud provider from database hosts
  # Uses case-insensitive contains check for aws/amazon, azure, gcp/goog/google
  # Try PostgreSQL host first, then Redis host, then default to "aws"
  postgres_host = try(var.infra_vars.postgres.value, null) != null && length(keys(try(var.infra_vars.postgres.value, {}))) > 0 ? try(var.infra_vars.postgres.value[keys(try(var.infra_vars.postgres.value, {}))[0]].host, null) : null
  redis_host    = try(var.infra_vars.redis.value, null) != null && length(keys(try(var.infra_vars.redis.value, {}))) > 0 ? try(var.infra_vars.redis.value[keys(try(var.infra_vars.redis.value, {}))[0]].host, null) : null

  host_to_check = try(local.postgres_host, local.redis_host, null)
  host_lower    = local.host_to_check != null ? lower(local.host_to_check) : ""

  detected_cloud = local.host_to_check != null ? (
    strcontains(local.host_lower, "aws") || strcontains(local.host_lower, "amazon") ? "aws" : (
      strcontains(local.host_lower, "azure") ? "azure" : (
        strcontains(local.host_lower, "gcp") || strcontains(local.host_lower, "goog") || strcontains(local.host_lower, "google") ? "gcp" : "unknown"
      )
    )
  ) : "aws" # Default to aws if no host available

  connection_environment = var.customer_facing ? "prod" : "staging"

  postgres_connections = try(var.infra_vars.postgres.value, null) != null ? {
    for db_schema, db_config in var.infra_vars.postgres.value :
    "postgres-${db_schema}" => {
      name    = length(keys(var.infra_vars.postgres.value)) == 1 ? "${var.organization}-postgres-db" : "${var.organization}-${db_schema}-db"
      type    = "database"
      subtype = "postgres"
      command = null
      secrets = {
        "envvar:HOST"    = db_config.host
        "envvar:PORT"    = tostring(db_config.port)
        "envvar:USER"    = db_config.user
        "envvar:PASS"    = db_config.password
        "envvar:DB"      = db_config.database
        "envvar:SSLMODE" = try(db_config.sslmode, "disable")
      }
      access_mode_runbooks = "enabled"
      access_mode_exec     = "enabled"
      access_mode_connect  = "disabled"
      access_schema        = "enabled"
      guardrail_rules      = ["a85115f6-5ef3-4618-b70c-f7cccdc62c5a"]
      tags = {
        environment = local.connection_environment
        customer_facing = var.customer_facing
        criticality   = "critical"
        access-level  = "private"
        impact        = "high"
        service-type  = "database"
        database-type = "postgres"
        cloud         = local.detected_cloud
      }
    }
  } : {}

  # Unified connections map - combines all non-PostgreSQL connection types
  connections_merge = merge(
    # Redis connections
    try(var.infra_vars.redis.value, null) != null ? {
      for instance_name, instance_config in var.infra_vars.redis.value :
      "redis-${instance_name}" => {
        name    = "${var.organization}-redis-${instance_name}"
        type    = "custom"
        subtype = "redis"
        command = ["redis-cli", "-h", "$HOST", "-p", "$PORT", "-n", "$DB_NUMBER"]
        secrets = {
          "envvar:HOST"      = instance_config.host
          "envvar:PORT"      = tostring(instance_config.port)
          "envvar:DB_NUMBER" = tostring(try(instance_config.db_number, 0))
        }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "disabled"
        access_schema        = "disabled"
        guardrail_rules      = ["182f59b2-5d5d-4ab8-978e-94472b3915fc"]
        tags = {
          environment = local.connection_environment
          customer_facing = var.customer_facing
          criticality   = "critical"
          access-level  = "private"
          impact        = "high"
          service-type  = "cache"
          database-type = "redis"
          cloud         = local.detected_cloud
        }
      }
    } : {},
    # Standard application connections
    # pgadmin
    try(var.infra_vars.postgres.value, null) != null ? {
      "pgadmin" = {
        name    = "${var.organization}-pgadmin"
        type    = "application"
        subtype = "tcp"
        command = ["bash"]
        secrets = {
          "envvar:HOST" = "pgadmin.paragon"
          "envvar:PORT" = "5050"
        }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        reviewers            = var.customer_facing ? ["admin", "paragon-admin"] : null
        tags = {
          environment = local.connection_environment
          customer_facing = var.customer_facing
          criticality  = "critical"
          access-level = "private"
          impact       = "high"
          service-type = "database"
          cloud        = local.detected_cloud
        }
      }
    } : {},
    # openobserve
    {
      "openobserve" = {
        name    = "${var.organization}-openobserve"
        type    = "application"
        subtype = "tcp"
        command = ["bash"]
        secrets = {
          "envvar:HOST" = "openobserve.paragon"
          "envvar:PORT" = "5080"
        }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        tags = {
          environment = local.connection_environment
          customer_facing = var.customer_facing
          criticality  = "normal"
          access-level = "private"
          impact       = "low"
          service-type = "storage"
          cloud        = local.detected_cloud
        }
      }
    },
    # redis-insight
    try(var.infra_vars.redis.value, null) != null ? {
      "redis-insight" = {
        name    = "${var.organization}-redis-insight"
        type    = "application"
        subtype = "tcp"
        command = ["bash"]
        secrets = {
          "envvar:HOST" = "redis-insight.paragon"
          "envvar:PORT" = "8500"
        }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        reviewers            = var.customer_facing ? ["admin", "paragon-admin"] : null
        tags = {
          environment = local.connection_environment
          customer_facing = var.customer_facing
          criticality  = "critical"
          access-level = "private"
          impact       = "high"
          service-type = "database"
          cloud        = local.detected_cloud
        }
      }
    } : {},
    # K8s connections from tfvars (or default k8s-admin if none defined)
    length(var.k8s_connections) > 0 ? {
      for conn_name, conn_config in var.k8s_connections :
      "k8s-${conn_name}" => {
        name    = "${var.organization}-k8s-${conn_name}"
        type    = try(conn_config.type, "custom")
        subtype = try(conn_config.subtype, null) != null && try(conn_config.subtype, null) != "" ? conn_config.subtype : null
        command = try(conn_config.command, ["bash"])
        secrets = merge(
          {
            "envvar:REMOTE_URL"           = try(conn_config.remote_url, "https://kubernetes.default.svc.cluster.local")
            "envvar:INSECURE"             = try(conn_config.insecure, "true")
            "envvar:KUBECTL_NAMESPACE"    = try(conn_config.namespace, "paragon")
            "envvar:HEADER_AUTHORIZATION" = "Bearer ${try(data.kubernetes_secret.hoop_cluster_admin_token[0].data["token"], "")}"
          },
          try(conn_config.secrets, {})
        )
        access_mode_runbooks = try(conn_config.access_mode_runbooks, "enabled")
        access_mode_exec     = try(conn_config.access_mode_exec, "enabled")
        access_mode_connect  = try(conn_config.access_mode_connect, "enabled")
        access_schema        = try(conn_config.access_schema, "disabled")
        guardrail_rules      = try(conn_config.guardrail_rules, null) != null && length(try(conn_config.guardrail_rules, [])) > 0 ? conn_config.guardrail_rules : null
        reviewers            = try(conn_config.reviewers, null) != null && length(try(conn_config.reviewers, [])) > 0 ? conn_config.reviewers : null
        tags = merge({
          environment = local.connection_environment
          customer_facing = var.customer_facing
          criticality  = "critical"
          access-level = "private"
          impact       = "high"
          service-type = "compute"
          cloud        = local.detected_cloud
          team         = "platform-eng"
        }, try(conn_config.tags, {}))
      }
      } : {
      # Default k8s-admin connection if no k8s_connections defined
      "k8s-admin" = {
        name    = "${var.organization}-k8s-admin"
        type    = "custom"
        subtype = null
        command = ["bash"]
        secrets = {
          "envvar:REMOTE_URL"           = "https://kubernetes.default.svc.cluster.local"
          "envvar:INSECURE"             = "true"
          "envvar:KUBECTL_NAMESPACE"    = "paragon"
          "envvar:HEADER_AUTHORIZATION" = "Bearer ${try(data.kubernetes_secret.hoop_cluster_admin_token[0].data["token"], "")}"
        }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        guardrail_rules      = null
        reviewers            = null
        tags = {
          environment = local.connection_environment
          customer_facing = var.customer_facing
          criticality  = "critical"
          access-level = "private"
          impact       = "high"
          service-type = "compute"
          cloud        = local.detected_cloud
          team         = "platform-eng"
        }
      }
    },
    # Custom connections from tfvars
    try(var.custom_connections, {}) != {} ? {
      for conn_name, conn_config in var.custom_connections :
      "custom-${conn_name}" => {
        name                 = "${var.organization}-${conn_name}"
        type                 = conn_config.type
        subtype              = try(conn_config.subtype, null) != null && try(conn_config.subtype, null) != "" ? conn_config.subtype : null
        command              = try(conn_config.command, null)
        secrets              = conn_config.secrets
        access_mode_runbooks = try(conn_config.access_mode_runbooks, "enabled")
        access_mode_exec     = try(conn_config.access_mode_exec, "enabled")
        access_mode_connect  = try(conn_config.access_mode_connect, "disabled")
        access_schema        = try(conn_config.access_schema, "disabled")
        guardrail_rules      = try(conn_config.guardrail_rules, null) != null && length(try(conn_config.guardrail_rules, [])) > 0 ? conn_config.guardrail_rules : null
        reviewers            = try(conn_config.reviewers, null) != null && length(try(conn_config.reviewers, [])) > 0 ? conn_config.reviewers : null
        tags = merge({
          environment = local.connection_environment
          customer_facing = var.customer_facing
          cloud           = try(conn_config.tags["cloud"], local.detected_cloud)
        }, try(conn_config.tags, {}))
      }
    } : {}
  )

  access_control_groups = {
    for conn_name, conn_config in local.all_connections :
    conn_name => (
      var.customer_facing
        ? ["dev-oncall", "paragon-admin"]
        : ["dev-oncall", "paragon-admin", "dev-engineering"]
    )
  }

  postgres_access_control_groups = {
    for conn_name, conn_config in local.postgres_connections :
    conn_name => (
      var.customer_facing
        ? ["dev-oncall", "paragon-admin"]
        : ["dev-oncall", "paragon-admin", "dev-engineering"]
    )
  }

  all_connections = local.connections_merge
}
