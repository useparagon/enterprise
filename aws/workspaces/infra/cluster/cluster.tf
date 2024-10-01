# Creating the EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.2"

  cluster_name    = var.workspace
  cluster_version = var.eks_k8s_version

  # networking
  cluster_endpoint_public_access = true
  subnet_ids                     = var.private_subnet.*.id
  vpc_id                         = var.vpc.id

  # access
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
  access_entries = {
    for username, entry in var.eks_admin_user_arns : username => {
      kubernetes_groups = entry.groups
      principal_arn     = entry.userarn

      policy_associations = {
        username = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            namespaces = ["default", "paragon"]
            type       = "namespace"
          }
        }
      }
    }
  }

  # encryption
  create_kms_key                  = false
  enable_kms_key_rotation         = true
  kms_key_deletion_window_in_days = 7
  cluster_encryption_config = {
    provider_key_arn = module.cluster_kms_key.key_arn
    resources        = ["secrets"]
  }

  cluster_tags = {
    Name = var.workspace
  }
}

resource "random_string" "node_group" {
  for_each = local.nodes

  length  = 6
  special = false
  numeric = false
  lower   = true
  upper   = false
  keepers = {
    workspace      = var.workspace
    iam_role_arn   = aws_iam_role.node_role.arn
    subnet_ids     = join(",", var.private_subnet.*.id)
    capacity_type  = each.value.capacity
    instance_types = join(",", each.value.instance_types)
  }
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.24.2"

  for_each = local.nodes

  name            = substr("${var.workspace}-${random_string.node_group[each.key].result}", 0, 38)
  use_name_prefix = true

  cluster_name                      = module.eks.cluster_name
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_cidr              = module.eks.cluster_service_cidr
  cluster_version                   = module.eks.cluster_version

  create_iam_role        = false
  iam_role_arn           = aws_iam_role.node_role.arn
  subnet_ids             = var.private_subnet.*.id
  vpc_security_group_ids = [module.eks.cluster_security_group_id]

  capacity_type  = each.value.capacity
  desired_size   = each.value.min_count
  instance_types = each.value.instance_types
  max_size       = each.value.max_count
  min_size       = each.value.min_count

  metadata_options = local.metadata_options
  labels = {
    "useparagon.com/capacityType" = each.key
  }
  update_config = {
    max_unavailable_percentage = 33
  }
  ebs_optimized           = true
  disable_api_termination = false
  enable_monitoring       = true
  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = local.node_volume_size
        volume_type           = "gp3"
        iops                  = 3000
        throughput            = 125
        encrypted             = true
        kms_key_id            = module.ebs_kms_key.key_arn
        delete_on_termination = true
      }
    }
  }

  depends_on = [
    module.eks,
    aws_iam_role.node_role,
    aws_iam_role_policy_attachment.custom_worker_policy_attachment,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy
  ]
}

resource "aws_eks_addon" "addons" {
  for_each = local.cluster_addons

  addon_name                  = each.key
  cluster_name                = module.eks.cluster_name
  configuration_values        = jsonencode(each.value)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  # certain addons such as coredns and EBS CNI require nodes
  depends_on = [module.eks_managed_node_group]
}
