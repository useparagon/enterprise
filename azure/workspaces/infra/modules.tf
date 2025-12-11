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

  cluster_name   = module.cluster.kubernetes.name
  k8s_version    = var.k8s_version
  private_subnet = module.network.private_subnet
  resource_group = module.network.resource_group
  ssh_whitelist  = local.ssh_whitelist
  tags           = local.default_tags
  workspace      = local.workspace
}

module "postgres" {
  source = "./postgres"

  managed_sync_enabled        = var.managed_sync_enabled
  postgres_multiple_instances = var.postgres_multiple_instances
  postgres_base_sku_name      = var.postgres_base_sku_name
  postgres_redundant          = var.postgres_redundant
  postgres_sku_name           = var.postgres_sku_name
  postgres_version            = var.postgres_version
  resource_group              = module.network.resource_group
  tags                        = local.default_tags
  virtual_network             = module.network.virtual_network
  private_subnet              = module.network.postgres_subnet
  workspace                   = local.workspace
}

module "redis" {
  source = "./redis"

  managed_sync_enabled     = var.managed_sync_enabled
  private_subnet           = module.network.private_subnet
  public_subnet            = module.network.public_subnet
  redis_base_capacity      = var.redis_base_capacity
  redis_base_sku_name      = var.redis_base_sku_name
  redis_capacity           = var.redis_capacity
  redis_multiple_instances = var.redis_multiple_instances
  redis_sku_name           = var.redis_sku_name
  redis_ssl_only           = var.redis_ssl_only
  redis_subnet             = module.network.redis_subnet
  resource_group           = module.network.resource_group
  tags                     = local.default_tags
  virtual_network          = module.network.virtual_network
  workspace                = local.workspace
}

module "storage" {
  source = "./storage"

  managed_sync_enabled       = var.managed_sync_enabled
  resource_group             = module.network.resource_group
  tags                       = local.default_tags
  virtual_network_subnet_ids = [module.network.public_subnet.id, module.network.private_subnet.id]
  workspace                  = local.workspace
}

module "cluster" {
  source = "./cluster"

  k8s_max_node_count              = var.k8s_max_node_count
  k8s_min_node_count              = var.k8s_min_node_count
  k8s_ondemand_node_instance_type = var.k8s_ondemand_node_instance_type
  k8s_sku_tier                    = var.k8s_sku_tier
  k8s_spot_instance_percent       = var.k8s_spot_instance_percent
  k8s_spot_node_instance_type     = var.k8s_spot_node_instance_type
  k8s_version                     = var.k8s_version
  private_subnet                  = module.network.private_subnet
  resource_group                  = module.network.resource_group
  tags                            = local.default_tags
  workspace                       = local.workspace
}

module "kafka" {
  count  = var.managed_sync_enabled ? 1 : 0
  source = "./kafka"

  eventhub_auto_inflate_enabled     = var.eventhub_auto_inflate_enabled
  eventhub_capacity                 = var.eventhub_capacity
  eventhub_maximum_throughput_units = var.eventhub_maximum_throughput_units
  eventhub_namespace_sku            = var.eventhub_namespace_sku
  private_subnet                    = module.network.private_subnet
  resource_group                    = module.network.resource_group
  tags                              = local.default_tags
  virtual_network                   = module.network.virtual_network
  workspace                         = local.workspace
}
