module "alb" {
  source = "./alb"

  certificate              = var.certificate
  cloudflare_dns_api_token = var.cloudflare_dns_api_token
  cloudflare_zone_id       = var.cloudflare_zone_id
  dns_provider             = var.dns_provider
  domain                   = var.domain
  public_microservices     = local.public_microservices
  public_monitors          = local.public_monitors
  release_ingress          = module.helm.release_ingress
  release_paragon_on_prem  = module.helm.release_paragon_on_prem
  workspace                = local.workspace
}

module "helm" {
  source = "./helm"

  certificate            = module.alb.certificate
  aws_region             = var.aws_region
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
  managed_sync_enabled   = var.managed_sync_enabled
  managed_sync_version   = var.managed_sync_version
  microservices          = local.microservices
  monitor_version        = local.monitor_version
  monitors               = local.monitors
  monitors_enabled       = var.monitors_enabled
  openobserve_email      = var.openobserve_email
  openobserve_password   = var.openobserve_password
  public_microservices   = local.public_microservices
  public_monitors        = local.public_monitors
  workspace              = local.workspace
}

module "managed_sync_config" {
  source = "./helm-config"
  count  = var.managed_sync_enabled ? 1 : 0

  aws_region       = var.aws_region
  base_helm_values = local.helm_vars
  infra_values     = local.infra_vars
  domain           = var.domain
  microservices    = local.microservices
}

module "monitors" {
  source = "./monitors"
  count  = var.monitors_enabled ? 1 : 0

  grafana_admin_email           = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_USER"], null)
  grafana_admin_password        = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD"], null)
  grafana_aws_access_key_id     = try(local.helm_vars.global.env["MONITOR_GRAFANA_AWS_ACCESS_ID"], null)
  grafana_aws_secret_access_key = try(local.helm_vars.global.env["MONITOR_GRAFANA_AWS_SECRET_KEY"], null)
  pgadmin_admin_email           = try(local.helm_vars.global.env["MONITOR_PGADMIN_EMAIL"], null)
  pgadmin_admin_password        = try(local.helm_vars.global.env["MONITOR_PGADMIN_PASSWORD"], null)
  workspace                     = local.workspace
}

module "uptime" {
  source = "./uptime"

  uptime_api_token = var.uptime_api_token
  uptime_company   = coalesce(var.uptime_company, var.organization)
  microservices    = local.uptime_services
}

module "hoop" {
  source = "./hoop"

  workspace          = local.workspace
  organization       = var.organization
  cluster_name       = local.cluster_name
  hoop_enabled       = var.hoop_enabled
  hoop_key           = var.hoop_key
  hoop_agent_id      = var.hoop_agent_id
  hoop_api_key       = var.hoop_api_key
  customer_facing    = var.customer_facing
  namespace_paragon  = module.helm.namespace_paragon
  custom_connections = var.hoop_custom_connections
  k8s_connections    = var.hoop_k8s_connections
  infra_vars = {
    postgres = try(local.infra_vars.postgres, null)
    redis    = try(local.infra_vars.redis, null)
  }
}
