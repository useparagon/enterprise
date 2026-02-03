module "helm" {
  source = "./helm"

  cluster_name           = local.cluster_name
  docker_email           = var.docker_email
  docker_password        = var.docker_password
  docker_registry_server = var.docker_registry_server
  docker_username        = var.docker_username
  feature_flags_content  = local.feature_flags_content
  flipt_options          = local.flipt_options
  helm_values            = local.helm_values
  ingress_scheme         = var.ingress_scheme
  k8s_version            = var.k8s_version
  logs_bucket            = local.logs_bucket
  microservices          = local.microservices
  monitor_version        = local.monitor_version
  monitors               = local.monitors
  monitors_enabled       = var.monitors_enabled
  openobserve_email      = var.openobserve_email
  openobserve_password   = var.openobserve_password
  public_microservices   = local.public_microservices
  public_monitors        = local.public_monitors
  resource_group         = local.infra_vars.resource_group.value
  workspace              = local.workspace
}

module "hoop" {
  source = "./hoop"

  workspace                     = local.workspace
  organization                  = var.organization
  cluster_name                  = local.cluster_name
  resource_group                = local.infra_vars.resource_group.value
  hoop_enabled                  = var.hoop_enabled
  hoop_key                      = var.hoop_key
  hoop_agent_id                 = var.hoop_agent_id
  hoop_api_key                  = var.hoop_api_key
  hoop_slack_bot_token          = var.hoop_slack_bot_token
  hoop_slack_app_token          = var.hoop_slack_app_token
  hoop_slack_channel_ids        = var.hoop_slack_channel_ids
  all_access_groups             = var.hoop_all_access_groups
  restricted_access_groups      = var.hoop_restricted_access_groups
  reviewers_access_groups       = var.hoop_reviewers_access_groups
  hoop_postgres_guardrail_rules = var.hoop_postgres_guardrail_rules
  hoop_redis_guardrail_rules    = var.hoop_redis_guardrail_rules
  customer_facing               = var.customer_facing
  namespace_paragon             = module.helm.namespace_paragon
  custom_connections            = var.hoop_custom_connections
  k8s_connections               = var.hoop_k8s_connections
  infra_vars = {
    postgres = try(local.infra_vars.postgres, null)
    redis    = try(local.infra_vars.redis, null)
  }
}

module "monitors" {
  source = "./monitors"
  count  = var.monitors_enabled ? 1 : 0

  grafana_admin_email    = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_USER"], null)
  grafana_admin_password = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD"], null)
  pgadmin_admin_email    = try(local.helm_vars.global.env["MONITOR_PGADMIN_EMAIL"], null)
  pgadmin_admin_password = try(local.helm_vars.global.env["MONITOR_PGADMIN_PASSWORD"], null)
  workspace              = local.workspace
}

module "uptime" {
  source = "./uptime"

  uptime_api_token = var.uptime_api_token
  uptime_company   = coalesce(var.uptime_company, var.organization)
  microservices    = local.uptime_services
}

module "dns" {
  source = "./dns"

  enabled              = local.dns_enabled
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  domain               = var.domain
  ingress_loadbalancer = module.helm.load_balancer
  public_services      = var.ingress_scheme == "internal" ? {} : local.public_services
}
