module "network" {
  source = "./network"

  gcp_project_id = local.gcp_project_id
  region         = var.region
  vpc_cidr       = var.vpc_cidr
  workspace      = local.workspace
}

module "bastion" {
  source = "./bastion"

  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_tunnel_account_id   = var.cloudflare_tunnel_account_id
  cloudflare_tunnel_email_domain = var.cloudflare_tunnel_email_domain
  cloudflare_tunnel_enabled      = var.cloudflare_tunnel_enabled
  cloudflare_tunnel_subdomain    = var.cloudflare_tunnel_subdomain
  cloudflare_tunnel_zone_id      = var.cloudflare_tunnel_zone_id

  cluster_name   = "TODO"
  gcp_project_id = local.gcp_project_id
  network        = module.network.network
  k8s_version    = var.k8s_version
  private_subnet = module.network.private_subnet
  region         = var.region
  workspace      = local.workspace
}
