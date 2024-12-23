locals {
  key_administrators = distinct(compact(concat(
    coalesce(var.eks_admin_arns, []),
    [var.kms_admin_role != null ? var.kms_admin_role : data.aws_caller_identity.current.arn]
  )))
}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.0"

  description             = "${var.workspace} ebs encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  aliases_use_name_prefix = false

  key_administrators = local.key_administrators

  key_service_roles_for_autoscaling = [
    # required for the ASG to manage encrypted volumes for nodes - since this role is unique to an account we can't reliably create it
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    # required for the cluster / persistentvolume-controller to create encrypted PVCs
    module.eks.cluster_iam_role_arn,
  ]
  computed_aliases = {
    ebs = { name = "eks/${var.workspace}/ebs" }
  }
}

module "cluster_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.0"

  description             = "${var.workspace} cluster encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  aliases_use_name_prefix = false

  key_administrators = local.key_administrators

  key_users = [
    module.eks.cluster_iam_role_arn
  ]
  computed_aliases = {
    cluster = { name = "eks/${var.workspace}/cluster" }
  }
}
