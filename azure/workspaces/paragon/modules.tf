# module "alb" {
#   source = "./alb"

#   acm_certificate_arn      = var.acm_certificate_arn
#   cloudflare_dns_api_token = var.cloudflare_dns_api_token
#   cloudflare_zone_id       = var.cloudflare_zone_id
#   dns_provider             = var.dns_provider
#   domain                   = var.domain
#   microservices            = local.microservices
#   public_monitors          = local.public_monitors
#   release_ingress          = module.helm.release_ingress
#   release_paragon_on_prem  = module.helm.release_paragon_on_prem
#   workspace                = local.workspace
# }

# module "helm" {
#   source = "./helm"

#   acm_certificate_arn    = module.alb.acm_certificate_arn
#   aws_region             = var.aws_region
#   cluster_name           = local.cluster_name
#   docker_email           = var.docker_email
#   docker_password        = var.docker_password
#   docker_registry_server = var.docker_registry_server
#   docker_username        = var.docker_username
#   helm_values            = local.helm_values
#   ingress_scheme         = var.ingress_scheme
#   k8s_version            = var.k8s_version
#   logs_bucket            = local.logs_bucket
#   microservices          = local.microservices
#   monitor_version        = local.monitor_version
#   monitors               = local.monitors
#   monitors_enabled       = var.monitors_enabled
#   openobserve_email      = var.openobserve_email
#   openobserve_password   = var.openobserve_password
#   public_monitors        = local.public_monitors
#   workspace              = local.workspace
# }

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
  microservices    = local.microservices
}
