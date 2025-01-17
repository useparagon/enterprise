module "network" {
  source = "./network"

  gcp_project_id = local.gcp_project_id
  region         = var.region
  vpc_cidr       = var.vpc_cidr
  workspace      = local.workspace
}
