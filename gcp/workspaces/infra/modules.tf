module "network" {
  source = "./network"

  gcp_project_id = local.gcp_project_id
  region         = var.region
  vpc_cidr       = var.vpc_cidr
  workspace      = local.workspace
}

module "postgres" {
  source = "./postgres"

  auditlogs_lock_enabled      = var.auditlogs_lock_enabled
  auditlogs_retention_days    = var.auditlogs_retention_days
  disable_deletion_protection = var.disable_deletion_protection
  gcp_project_id              = local.gcp_project_id
  network                     = module.network.network
  postgres_multiple_instances = var.postgres_multiple_instances
  postgres_tier               = var.postgres_tier
  private_subnet              = module.network.private_subnet
  region                      = var.region
  workspace                   = local.workspace
  managed_sync_enabled        = var.managed_sync_enabled
}

module "redis" {
  source = "./redis"

  gcp_project_id       = local.gcp_project_id
  multi_redis          = var.redis_multiple_instances
  network              = module.network.network
  private_subnet       = module.network.private_subnet
  redis_memory_size    = var.redis_memory_size
  region               = var.region
  region_zone          = var.region_zone
  region_zone_backup   = var.region_zone_backup
  workspace            = local.workspace
  managed_sync_enabled = var.managed_sync_enabled
}

module "kafka" {
  count  = var.managed_sync_enabled ? 1 : 0
  source = "./kafka"

  gcp_project_id     = local.gcp_project_id
  region             = var.region
  workspace          = local.workspace
  private_subnet_uri = module.network.private_subnet.self_link
  gmk_vcpu_count     = var.gmk_vcpu_count
  gmk_memory_bytes   = var.gmk_memory_gib * 1024 * 1024 * 1024
  gmk_disk_size_gib  = var.gmk_disk_size_gib
  gmk_auto_rebalance          = var.gmk_auto_rebalance
  gmk_kafka_version           = var.gmk_kafka_version
  gmk_sasl_mechanism          = var.gmk_sasl_mechanism
  gmk_sasl_plain_key_file_path = var.gmk_sasl_plain_key_file_path
}

module "storage" {
  source = "./storage"

  auditlogs_lock_enabled      = var.auditlogs_lock_enabled
  auditlogs_retention_days    = var.auditlogs_retention_days
  disable_deletion_protection = var.disable_deletion_protection
  gcp_project_id              = local.gcp_project_id
  region                      = var.region
  use_storage_account_key     = var.use_storage_account_key
  workspace                   = local.workspace
  managed_sync_enabled        = var.managed_sync_enabled
}

module "cluster" {
  source = "./cluster"

  disable_deletion_protection     = var.disable_deletion_protection
  disable_public_endpoint         = var.k8s_disable_public_endpoint
  gcp_project_id                  = local.gcp_project_id
  k8s_max_node_count              = var.k8s_max_node_count
  k8s_min_node_count              = var.k8s_min_node_count
  k8s_ondemand_node_instance_type = var.k8s_ondemand_node_instance_type
  k8s_spot_instance_percent       = var.k8s_spot_instance_percent
  k8s_spot_node_instance_type     = var.k8s_spot_node_instance_type
  k8s_version                     = var.k8s_version
  network                         = module.network.network
  private_subnet                  = module.network.private_subnet
  region                          = var.region
  region_zone                     = var.region_zone
  region_zone_backup              = var.region_zone_backup
  workspace                       = local.workspace
}

module "bastion" {
  source = "./bastion"

  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_tunnel_account_id   = var.cloudflare_tunnel_account_id
  cloudflare_tunnel_email_domain = var.cloudflare_tunnel_email_domain
  cloudflare_tunnel_enabled      = var.cloudflare_tunnel_enabled
  cloudflare_tunnel_subdomain    = var.cloudflare_tunnel_subdomain
  cloudflare_tunnel_zone_id      = var.cloudflare_tunnel_zone_id

  cluster_name    = module.cluster.kubernetes.name
  gcp_project_id  = local.gcp_project_id
  network         = module.network.network
  k8s_version     = var.k8s_version
  private_subnet  = module.network.private_subnet
  region          = var.region
  region_zone     = var.region_zone
  ssh_whitelist   = local.ssh_whitelist
  tfc_agent_token = var.tfc_agent_token
  workspace       = local.workspace
}
