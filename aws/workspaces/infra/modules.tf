module "network" {
  source = "./network"

  workspace        = local.workspace
  aws_region       = var.aws_region
  az_count         = var.az_count
  vpc_cidr         = var.vpc_cidr
  vpc_cidr_newbits = var.vpc_cidr_newbits
}

module "cloudtrail" {
  count  = var.disable_cloudtrail ? 0 : 1
  source = "./cloudtrail"

  workspace                   = local.workspace
  aws_region                  = var.aws_region
  master_guardduty_account_id = var.master_guardduty_account_id
  mfa_enabled                 = var.mfa_enabled
  force_destroy               = var.disable_deletion_protection
}

module "postgres" {
  source = "./postgres"

  workspace                   = local.workspace
  aws_region                  = var.aws_region
  rds_instance_class          = var.rds_instance_class
  rds_multi_az                = var.rds_multi_az
  rds_multiple_instances      = var.rds_multiple_instances
  rds_postgres_version        = var.rds_postgres_version
  rds_restore_from_snapshot   = var.rds_restore_from_snapshot
  rds_final_snapshot_enabled  = var.rds_final_snapshot_enabled
  disable_deletion_protection = var.disable_deletion_protection
  managed_sync_enabled        = var.managed_sync_enabled

  vpc                = module.network.vpc
  public_subnet      = module.network.public_subnet
  private_subnet     = module.network.private_subnet
  availability_zones = module.network.availability_zones
}

module "redis" {
  source = "./redis"

  workspace                      = local.workspace
  aws_region                     = var.aws_region
  elasticache_node_type          = var.elasticache_node_type
  elasticache_multi_az           = var.elasticache_multi_az
  elasticache_multiple_instances = var.elasticache_multiple_instances
  managed_sync_enabled           = var.managed_sync_enabled

  vpc            = module.network.vpc
  public_subnet  = module.network.public_subnet
  private_subnet = module.network.private_subnet
}

module "storage" {
  source = "./storage"

  workspace             = local.workspace
  force_destroy         = var.disable_deletion_protection
  app_bucket_expiration = var.app_bucket_expiration
  managed_sync_enabled  = var.managed_sync_enabled
}

module "kafka" {
  source = "./kafka"
  count  = var.managed_sync_enabled ? 1 : 0

  workspace         = local.workspace
  force_destroy     = var.disable_deletion_protection
  msk_kafka_version = var.msk_kafka_version
  msk_instance_type = var.msk_instance_type

  private_subnet = module.network.private_subnet
  vpc_id         = module.network.vpc.id
  logs_bucket    = module.storage.s3.logs_bucket
}

module "bastion" {
  source = "./bastion"

  workspace     = local.workspace
  aws_region    = var.aws_region
  ssh_whitelist = local.ssh_whitelist

  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_tunnel_enabled      = var.cloudflare_tunnel_enabled
  cloudflare_tunnel_subdomain    = var.cloudflare_tunnel_subdomain
  cloudflare_tunnel_zone_id      = var.cloudflare_tunnel_zone_id
  cloudflare_tunnel_account_id   = var.cloudflare_tunnel_account_id
  cloudflare_tunnel_email_domain = var.cloudflare_tunnel_email_domain

  cluster_name   = local.workspace
  k8s_version    = var.k8s_version
  private_subnet = module.network.private_subnet
  public_subnet  = module.network.public_subnet
  vpc_id         = module.network.vpc.id
}

module "cluster" {
  source = "./cluster"

  workspace = local.workspace

  bastion_role_arn          = module.bastion.bastion_role_arn
  bastion_security_group_id = module.bastion.security_group.host[0]

  eks_admin_arns                  = var.eks_admin_arns
  eks_max_node_count              = var.eks_max_node_count
  eks_min_node_count              = var.eks_min_node_count
  eks_ondemand_node_instance_type = local.eks_ondemand_node_instance_type
  eks_spot_instance_percent       = var.eks_spot_instance_percent
  eks_spot_node_instance_type     = local.eks_spot_node_instance_type
  k8s_version                     = var.k8s_version

  vpc_id             = module.network.vpc.id
  private_subnet_ids = module.network.private_subnet[*].id
}
