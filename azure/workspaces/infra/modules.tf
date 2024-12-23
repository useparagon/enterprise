module "network" {
  source = "./network"

  location  = var.location
  tags      = local.default_tags
  vpc_cidr  = var.vpc_cidr
  workspace = local.workspace
}

module "bastion" {
  source = "./bastion"

  azure_client_id       = var.azure_client_id
  azure_client_secret   = var.azure_client_secret
  azure_subscription_id = var.azure_subscription_id
  azure_tenant_id       = var.azure_tenant_id

  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_tunnel_account_id   = var.cloudflare_tunnel_account_id
  cloudflare_tunnel_email_domain = var.cloudflare_tunnel_email_domain
  cloudflare_tunnel_enabled      = var.cloudflare_tunnel_enabled
  cloudflare_tunnel_subdomain    = var.cloudflare_tunnel_subdomain
  cloudflare_tunnel_zone_id      = var.cloudflare_tunnel_zone_id

  cluster_name   = "${local.workspace}-cluster" # TODO module.cluster.kubernetes.name
  k8s_version    = var.k8s_version
  private_subnet = module.network.private_subnet
  resource_group = module.network.resource_group
  ssh_whitelist  = local.ssh_whitelist
  tags           = local.default_tags
  workspace      = local.workspace
}

module "postgres" {
  source = "./postgres"

  postgres_redundant = var.postgres_redundant
  postgres_sku_name  = var.postgres_sku_name
  postgres_version   = var.postgres_version
  resource_group     = module.network.resource_group
  tags               = local.default_tags
  virtual_network    = module.network.virtual_network
  private_subnet     = module.network.postgres_subnet
  workspace          = local.workspace
}

module "storage" {
  source = "./storage"

  resource_group             = module.network.resource_group
  tags                       = local.default_tags
  virtual_network_subnet_ids = [module.network.public_subnet.id] # TODO allow access from AKS subnet
  workspace                  = local.workspace
}

# module "cluster" {
#   source = "./cluster"

# name = "${local.workspace}-cluster"

#   app_name                       = local.app_name
#   microservices                  = local.microservices
#   monitors                       = local.monitors
#   location                       = var.location
#   config_hash                    = var.config_hash
#   deployment_cache_buster        = var.deployment_cache_buster
#   logging_helm_hash              = var.logging_helm_hash
#   monitoring_helm_hash           = var.monitoring_helm_hash
#   onprem_helm_hash               = var.onprem_helm_hash
#   docker_username                = var.docker_username
#   docker_password                = var.docker_password
#   docker_email                   = var.docker_email
#   paragon_version                = var.paragon_version
#   k8_version                     = var.k8_version
#   k8_min_node_count              = var.k8_min_node_count
#   k8_max_node_count              = var.k8_max_node_count
#   k8_spot_instance_percent       = var.k8_spot_instance_percent
#   k8_ondemand_node_instance_type = var.k8_ondemand_node_instance_type
#   k8_spot_node_instance_type     = var.k8_spot_node_instance_type

#   domain                   = var.domain
#   cloudflare_dns_api_token = var.cloudflare_dns_api_token
#   cloudflare_zone_id       = var.cloudflare_zone_id
#   beethoven_postgres_port  = module.postgres.postgres.port

#   resource_group = module.network.resource_group
#   private_subnet = module.network.private_subnet
#   public_subnet  = module.network.public_subnet
# }

# module "helm" {
#   source = "./helm"

#   app_name                 = local.app_name
#   microservices            = local.microservices
#   monitors                 = local.monitors
#   location                 = var.location
#   config_hash              = var.config_hash
#   deployment_cache_buster  = var.deployment_cache_buster
#   docker_username          = var.docker_username
#   docker_password          = var.docker_password
#   docker_email             = var.docker_email
#   paragon_version          = var.paragon_version
#   monitor_version          = var.monitor_version
#   logging_version          = var.logging_version
#   logging_helm_hash        = var.logging_helm_hash
#   monitoring_helm_hash     = var.monitoring_helm_hash
#   onprem_helm_hash         = var.onprem_helm_hash
#   cloudflare_dns_api_token = var.cloudflare_dns_api_token
#   monitoring_enabled       = var.monitoring_enabled
#   k8_version               = var.k8_version

#   domain = var.domain

#   resource_group                  = module.network.resource_group
#   private_subnet                  = module.network.private_subnet
#   public_subnet                   = module.network.public_subnet
#   aks_cluster                     = module.cluster.kubernetes
#   wait_for_cluster                = module.cluster.wait_for_cluster
#   wait_for_cluster_ondemand_nodes = module.cluster.wait_for_cluster_ondemand_nodes
#   wait_for_cluster_spot_nodes     = module.cluster.wait_for_cluster_spot_nodes

#   environment_variables = {
#     for key, value in merge(local.env_docker, {
#       ORGANIZATION                            = var.organization
#       PARAGON_DOMAIN                          = var.domain
#       HOST_ENV                                = "AZURE_K8"
#       BRANCH                                  = "default"
#       BEETHOVEN_POSTGRES_HOST                 = module.postgres.postgres.host
#       BEETHOVEN_POSTGRES_PORT                 = module.postgres.postgres.port
#       BEETHOVEN_POSTGRES_USERNAME             = "${module.postgres.postgres.user}@${module.postgres.postgres.host}"
#       BEETHOVEN_POSTGRES_PASSWORD             = module.postgres.postgres.password
#       BEETHOVEN_POSTGRES_DATABASE             = module.postgres.postgres.database
#       CERBERUS_POSTGRES_HOST                  = module.postgres.postgres.host
#       CERBERUS_POSTGRES_PORT                  = module.postgres.postgres.port
#       CERBERUS_POSTGRES_USERNAME              = "${module.postgres.postgres.user}@${module.postgres.postgres.host}"
#       CERBERUS_POSTGRES_PASSWORD              = module.postgres.postgres.password
#       CERBERUS_POSTGRES_DATABASE              = module.postgres.postgres.database
#       HERMES_POSTGRES_HOST                    = module.postgres.postgres.host
#       HERMES_POSTGRES_PORT                    = module.postgres.postgres.port
#       HERMES_POSTGRES_USERNAME                = "${module.postgres.postgres.user}@${module.postgres.postgres.host}"
#       HERMES_POSTGRES_PASSWORD                = module.postgres.postgres.password
#       HERMES_POSTGRES_DATABASE                = module.postgres.postgres.database
#       PHEME_POSTGRES_HOST                     = module.postgres.postgres.host
#       PHEME_POSTGRES_PORT                     = module.postgres.postgres.port
#       PHEME_POSTGRES_USERNAME                 = "${module.postgres.postgres.user}@${module.postgres.postgres.host}"
#       PHEME_POSTGRES_PASSWORD                 = module.postgres.postgres.password
#       PHEME_POSTGRES_DATABASE                 = module.postgres.postgres.database
#       ZEUS_POSTGRES_HOST                      = module.postgres.postgres.host
#       ZEUS_POSTGRES_PORT                      = module.postgres.postgres.port
#       ZEUS_POSTGRES_USERNAME                  = "${module.postgres.postgres.user}@${module.postgres.postgres.host}"
#       ZEUS_POSTGRES_PASSWORD                  = module.postgres.postgres.password
#       ZEUS_POSTGRES_DATABASE                  = module.postgres.postgres.database
#       REDIS_URL                               = "${module.redis.redis.k8host}:${module.redis.redis.port}"
#       CACHE_REDIS_URL                         = "${module.redis.redis.k8host}:${module.redis.redis.port}"
#       SYSTEM_REDIS_URL                        = "${module.redis.redis.k8host}:${module.redis.redis.port}"
#       QUEUE_REDIS_URL                         = "${module.redis.redis.k8host}:${module.redis.redis.port}"
#       WORKFLOW_REDIS_URL                      = "${module.redis.redis.k8host}:${module.redis.redis.port}"
#       CACHE_REDIS_CLUSTER_ENABLED             = "false"
#       SYSTEM_REDIS_CLUSTER_ENABLED            = "false"
#       QUEUE_REDIS_CLUSTER_ENABLED             = "false"
#       WORKFLOW_REDIS_CLUSTER_ENABLED          = "false"
#       CERBERUS_PUBLIC_URL                     = "https://cerberus.${var.domain}"
#       CONNECT_PUBLIC_URL                      = "https://connect.${var.domain}"
#       DASHBOARD_PUBLIC_URL                    = "https://dashboard.${var.domain}"
#       HERCULES_PUBLIC_URL                     = "https://hercules.${var.domain}"
#       HERMES_PUBLIC_URL                       = "https://hermes.${var.domain}"
#       MINIO_PUBLIC_URL                        = "https://minio.${var.domain}"
#       PASSPORT_PUBLIC_URL                     = "https://passport.${var.domain}"
#       PHEME_PUBLIC_URL                        = "https://pheme.${var.domain}"
#       RELEASE_PUBLIC_URL                      = "https://release.${var.domain}"
#       ZEUS_PUBLIC_URL                         = "https://zeus.${var.domain}"
#       ACCOUNT_PORT                            = try(local.microservices.account.port, 1708)
#       CERBERUS_PORT                           = try(local.microservices.cerberus.port, 1700)
#       CHRONOS_PORT                            = try(local.microservices.chronos.port, 1708)
#       CONNECT_PORT                            = try(local.microservices.connect.port, 1707)
#       DASHBOARD_PORT                          = try(local.microservices.dashboard.port, 1704)
#       HADES_PORT                              = try(local.microservices.hades.port, 1710)
#       HERCULES_PORT                           = try(local.microservices.hercules.port, 1701)
#       HERMES_PORT                             = try(local.microservices.hermes.port, 1702)
#       PASSPORT_PORT                           = try(local.microservices.passport.port, 1706)
#       PHEME_PORT                              = try(local.microservices.pheme.port, 1709)
#       PLATO_PORT                              = try(local.microservices.plato.port, 1711)
#       RELEASE_PORT                            = try(local.microservices.release.port, 1719)
#       ZEUS_PORT                               = try(local.microservices.zeus.port, 1703)
#       WORKER_ACTIONS_PORT                     = try(local.microservices["worker-actions"].port, 1712)
#       WORKER_CREDENTIALS_PORT                 = try(local.microservices["worker-credentials"].port, 1713)
#       WORKER_CRONS_PORT                       = try(local.microservices["worker-crons"].port, 1714)
#       WORKER_DEPLOYMENTS_PORT                 = try(local.microservices["worker-deployments"].port, 1718)
#       WORKER_PROXY_PORT                       = try(local.microservices["worker-proxy"].port, 1715)
#       WORKER_TRIGGERS_PORT                    = try(local.microservices["worker-triggers"].port, 1716)
#       WORKER_WORKFLOWS_PORT                   = try(local.microservices["worker-workflows"].port, 1717)
#       ACCOUNT_PRIVATE_URL                     = "http://account:${try(local.microservices.account.port, 1708)}"
#       CERBERUS_PRIVATE_URL                    = "http://cerberus:${try(local.microservices.cerberus.port, 1700)}"
#       CHRONOS_PRIVATE_URL                     = "http://chronos:${try(local.microservices.chronos.port, 1708)}"
#       CONNECT_PRIVATE_URL                     = "http://connect:${try(local.microservices.connect.port, 1707)}"
#       DASHBOARD_PRIVATE_URL                   = "http://dashboard:${try(local.microservices.dashboard.port, 1704)}"
#       HADES_PRIVATE_URL                       = "http://hades:${try(local.microservices.hades.port, 1710)}"
#       HERCULES_PRIVATE_URL                    = "http://hercules:${try(local.microservices.hercules.port, 1701)}"
#       HERMES_PRIVATE_URL                      = "http://hermes:${try(local.microservices.hermes.port, 1702)}"
#       MINIO_PRIVATE_URL                       = "http://minio:${try(local.microservices.minio.port, 9000)}"
#       PASSPORT_PRIVATE_URL                    = "http://passport:${try(local.microservices.passport.port, 1706)}"
#       PHEME_PRIVATE_URL                       = "http://pheme:${try(local.microservices.pheme.port, 1709)}"
#       PLATO_PRIVATE_URL                       = "http://plato:${try(local.microservices.plato.port, 1711)}"
#       RELEASE_PRIVATE_URL                     = "http://release:${try(local.microservices.release.port, 1719)}"
#       ZEUS_PRIVATE_URL                        = "http://zeus:${try(local.microservices.zeus.port, 1703)}"
#       WORKER_ACTIONS_PRIVATE_URL              = "http://worker-actions:${try(local.microservices["worker-actions"].port, 1712)}"
#       WORKER_CREDENTIALS_PRIVATE_URL          = "http://worker-credentials:${try(local.microservices["worker-credentails"].port, 1713)}"
#       WORKER_CRONS_PRIVATE_URL                = "http://worker-crons:${try(local.microservices["worker-crons"].port, 1714)}"
#       WORKER_DEPLOYMENTS_PRIVATE_URL          = "http://worker-deployments:${try(local.microservices["worker-deployments"].port, 1718)}"
#       WORKER_PROXY_PRIVATE_URL                = "http://worker-proxy:${try(local.microservices["worker-proxy"].port, 1715)}"
#       WORKER_TRIGGERS_PRIVATE_URL             = "http://worker-triggers:${try(local.microservices["worker-triggers"].port, 1716)}"
#       WORKER_WORKFLOWS_PRIVATE_URL            = "http://worker-workflows:${try(local.microservices["worker-workflows"].port, 1717)}"
#       MINIO_BROWSER                           = "off"
#       MINIO_MODE                              = "gateway-azure"
#       MINIO_NGINX_PROXY                       = "on"
#       MINIO_INSTANCE_COUNT                    = "1"
#       MINIO_PORT                              = local.microservices.minio.port
#       MINIO_SYSTEM_BUCKET                     = module.storage.storage.private_container
#       MINIO_PUBLIC_BUCKET                     = module.storage.storage.public_container
#       MINIO_ROOT_USER                         = module.storage.storage.name
#       MINIO_ROOT_PASSWORD                     = module.storage.storage.access_key
#       MINIO_MICROSERVICE_USER                 = module.storage.storage.minio_microservice_user
#       MINIO_MICROSERVICE_PASS                 = module.storage.storage.minio_microservice_pass
#       MINIO_REGION                            = module.network.resource_group.location
#       MONITOR_BULL_EXPORTER_HOST              = "http://bull-exporter"
#       MONITOR_BULL_EXPORTER_PORT              = local.monitors["bull-exporter"].port
#       MONITOR_JAEGER_COLLECTOR_OTLP_GRPC_HOST = "http://jaegar"
#       MONITOR_JAEGER_COLLECTOR_OTLP_GRPC_PORT = local.monitors["jaegar"].port
#       MONITOR_GRAFANA_HOST                    = "http://grafana"
#       MONITOR_GRAFANA_PORT                    = local.monitors["grafana"].port
#       MONITOR_KUBE_STATE_METRICS_HOST         = "http://kube-state-metrics"
#       MONITOR_KUBE_STATE_METRICS_PORT         = local.monitors["kube-state-metrics"].port
#       MONITOR_PGADMIN_HOST                    = "http://pgadmin"
#       MONITOR_PGADMIN_PORT                    = local.monitors["pgadmin"].port
#       MONITOR_PGADMIN_EMAIL                   = "engineering@useparagon.com"
#       MONITOR_PGADMIN_PASSWORD                = "password"
#       MONITOR_PGADMIN_SSL_MODE                = "disable"
#       MONITOR_CACHE_REDIS_TARGETS             = "${local.app_name}-redis"
#       MONITOR_QUEUE_REDIS_TARGET              = "${local.app_name}-redis"
#       MONITOR_POSTGRES_EXPORTER_HOST          = "http://postgres-exporter"
#       MONITOR_POSTGRES_EXPORTER_PORT          = local.monitors["postgres-exporter"].port
#       MONITOR_POSTGRES_EXPORTER_SSL_MODE      = "disable"
#       MONITOR_PROMETHEUS_HOST                 = "http://prometheus"
#       MONITOR_PROMETHEUS_PORT                 = local.monitors["prometheus"].port
#       MONITOR_REDIS_EXPORTER_HOST             = "http://redis-exporter"
#       MONITOR_REDIS_EXPORTER_PORT             = local.monitors["redis-exporter"].port
#       MONITOR_REDIS_INSIGHT_HOST              = "http://redis-insight"
#       MONITOR_REDIS_INSIGHT_PORT              = local.monitors["redis-insight"].port
#     }) :
#     key => value
#     if key != null && key != "" && value != null && value != ""
#   }
# }

# module "redis" {
#   source = "./redis"

#   app_name       = local.app_name
#   vpc_cidr       = var.vpc_cidr
#   redis_capacity = parseint(var.redis_capacity, 10)

#   resource_group  = module.network.resource_group
#   virtual_network = module.network.virtual_network
#   private_subnet  = module.network.private_subnet
#   public_subnet   = module.network.public_subnet
# }

# module "alb" {
#   source = "./alb"

#   app_name                 = local.app_name
#   microservices            = local.microservices
#   ip_whitelist             = local.ip_whitelist
#   domain                   = var.domain
#   cloudflare_dns_api_token = var.cloudflare_dns_api_token
#   cloudflare_zone_id       = var.cloudflare_zone_id
#   public_services          = local.public_services

#   ingress_loadbalancer = module.helm.load_balancer
#   resource_group       = module.network.resource_group
#   private_subnet       = module.network.private_subnet
#   public_subnet        = module.network.public_subnet
# }
