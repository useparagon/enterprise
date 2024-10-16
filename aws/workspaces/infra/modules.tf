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
  disable_deletion_protection = var.disable_deletion_protection

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

  vpc            = module.network.vpc
  public_subnet  = module.network.public_subnet
  private_subnet = module.network.private_subnet
}

module "s3" {
  source = "./s3"

  workspace             = local.workspace
  force_destroy         = var.disable_deletion_protection
  app_bucket_expiration = var.app_bucket_expiration
}

module "cluster" {
  source = "./cluster"

  workspace                       = local.workspace
  eks_admins                      = local.eks_admins
  eks_k8s_version                 = var.eks_k8s_version
  eks_ondemand_node_instance_type = local.eks_ondemand_node_instance_type
  eks_spot_node_instance_type     = local.eks_spot_node_instance_type
  eks_spot_instance_percent       = var.eks_spot_instance_percent
  eks_min_node_count              = var.eks_min_node_count
  eks_max_node_count              = var.eks_max_node_count

  vpc_id             = module.network.vpc.id
  private_subnet_ids = module.network.private_subnet[*].id
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

  vpc_id           = module.network.vpc.id
  public_subnet    = module.network.public_subnet
  private_subnet   = module.network.private_subnet
  eks_cluster_name = module.cluster.eks_cluster.name
}
