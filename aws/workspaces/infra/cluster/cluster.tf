# Creating the EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.2"

  cluster_name                   = var.workspace
  cluster_version                = var.eks_k8s_version
  vpc_id                         = var.vpc.id
  subnet_ids                     = var.private_subnet.*.id
  cluster_endpoint_public_access = true
  create_aws_auth_configmap      = true

  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.node_role.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
    {
      rolearn  = var.bastion_role_arn
      username = "system:node:{{EC2PrivateDNSName}}",
      groups   = ["system:masters"]
    }
  ]

  # If these aren't available when the cluster is first initialized, it'll have to be manually created
  # https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html
  aws_auth_users = var.eks_admin_user_arns

  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]

  aws_auth_node_iam_role_arns_non_windows = [
    aws_iam_role.node_role.arn
  ]

  # Encryption key
  create_kms_key = false
  cluster_encryption_config = [{
    provider_key_arn = module.cluster_kms_key.key_arn
    resources        = ["secrets"]
  }]
  kms_key_deletion_window_in_days = 7
  enable_kms_key_rotation         = true

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_ntp_ipv4_cidr_block = ["169.254.169.123/32"]
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    attach_cluster_primary_security_group = true
  }

  cluster_tags = {
    Name = var.workspace
  }
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name                = var.workspace
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.19.0-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.aws_ebs_csi_driver_iam_role[0].iam_role_arn

  depends_on = [
    module.eks_managed_node_group
  ]
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

  name            = "${var.workspace}-${random_string.node_group[each.key].result}"
  use_name_prefix = true
  cluster_name    = module.eks.cluster_name
  cluster_version = module.eks.cluster_version

  vpc_id                            = var.vpc.id
  subnet_ids                        = var.private_subnet.*.id
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_security_group_id         = module.eks.cluster_security_group_id
  vpc_security_group_ids = [
    module.eks.cluster_security_group_id,
  ]
  security_group_rules = local.node_security_group_rules
  create_iam_role      = false
  iam_role_arn         = aws_iam_role.node_role.arn

  min_size       = each.value.min_count
  max_size       = each.value.max_count
  desired_size   = each.value.min_count
  capacity_type  = each.value.capacity
  instance_types = each.value.instance_types

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
