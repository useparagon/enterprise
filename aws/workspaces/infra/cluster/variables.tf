variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "vpc_id" {
  description = "The ID of VPC to create resources in."
  type        = string
}

variable "private_subnet_ids" {
  description = "The private subnet IDs within the VPC."
  type        = list(string)
}

variable "eks_admin_arns" {
  description = "Array of ARNs for IAM users, groups or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard."
  type        = list(string)
  default     = []
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "eks_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes nodes."
  type        = list(string)
}

variable "eks_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = list(string)
}

variable "eks_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
}

variable "eks_min_node_count" {
  description = "The minimum number of nodes to run in the Kubernetes cluster."
  type        = number
}

variable "eks_max_node_count" {
  description = "The maximum number of nodes to run in the Kubernetes cluster."
  type        = number
}

variable "kms_admin_role" {
  description = "ARN of IAM role allowed to administer KMS keys."
  type        = string
  default     = null
}

variable "bastion_role_arn" {
  description = "ARN of IAM role associated with Bastion."
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security Group ID associated with Bastion."
  type        = string
}

variable "create_autoscaling_linked_role" {
  description = "Whether or not to create an IAM role for autoscaling."
  type        = bool
}

data "aws_caller_identity" "current" {}

locals {
  node_volume_size = 50

  nodes = {
    for key, value in {
      ondemand = var.eks_spot_instance_percent == 100 ? null : {
        min_count      = ceil(var.eks_min_node_count * (1 - (var.eks_spot_instance_percent / 100)))
        max_count      = ceil(var.eks_max_node_count * (1 - (var.eks_spot_instance_percent / 100)))
        instance_types = var.eks_ondemand_node_instance_type
        capacity       = "ON_DEMAND"
      }
      spot = var.eks_spot_instance_percent == 0 ? null : {
        min_count      = floor(var.eks_min_node_count * (var.eks_spot_instance_percent / 100))
        max_count      = ceil(var.eks_max_node_count * (var.eks_spot_instance_percent / 100))
        instance_types = var.eks_spot_node_instance_type
        capacity       = "SPOT"
      }
    } : key => value
    if value != null
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      version = "v1.55.0-eksbuild.2"
    }
    coredns = {
      version = "v1.11.4-eksbuild.28"
    }
    kube-proxy = {
      version = "v1.32.11-eksbuild.2"
    }
    vpc-cni = {
      version = "v1.21.1-eksbuild.3"
    }
  }

  # We need to lookup K8s taint effect from the AWS API value
  taint_effects = {
    NO_SCHEDULE        = "NoSchedule"
    NO_EXECUTE         = "NoExecute"
    PREFER_NO_SCHEDULE = "PreferNoSchedule"
  }

  cluster_autoscaler_label_tags = merge([
    for name, group in module.eks.eks_managed_node_groups : {
      for label_name, label_value in coalesce(group.node_group_labels, {}) : "${name}|label|${label_name}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0],
        key               = "k8s.io/cluster-autoscaler/node-template/label/${label_name}",
        value             = label_value,
      }
    }
  ]...)

  cluster_autoscaler_taint_tags = merge([
    for name, group in module.eks.eks_managed_node_groups : {
      for taint in coalesce(group.node_group_taints, []) : "${name}|taint|${taint.key}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0],
        key               = "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}"
        value             = "${taint.value}:${local.taint_effects[taint.effect]}"
      }
    }
  ]...)

  cluster_autoscaler_asg_tags = merge(local.cluster_autoscaler_label_tags, local.cluster_autoscaler_taint_tags)

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # when using an assumed role the role itself must be used instead of the current identity arn
  # so convert identity arn (e.g. arn:aws:sts::123456789:assumed-role/ParagonAssumedRole/SessionName)
  # to role arn (e.g. arn:aws:iam::123456789:role/ParagonAssumedRole)
  is_assumed_role = can(regex("assumed-role", data.aws_caller_identity.current.arn))
  assumed_role_parts = split(
    "/",
    replace(
      replace(
        data.aws_caller_identity.current.arn,
        ":sts:",
        ":iam:"
      ),
      ":assumed-role/",
      # in the case of AWS SSO, the arn is in the format of arn:aws:sts::123456789:assumed-role/ParagonAssumedRole/SessionName
      # but we need to convert it to arn:aws:iam::123456789:role/aws-reserved/sso.amazonaws.com/ParagonAssumedRole
      local.is_assumed_role && strcontains(data.aws_caller_identity.current.arn, ":assumed-role/AWSReservedSSO") ? ":role__TEMPORARY_DIVIDER__aws-reserved__TEMPORARY_DIVIDER__sso.amazonaws.com/" : ":role/"
    )
  )
  caller_arn = local.is_assumed_role ? replace(format("%s/%s", local.assumed_role_parts[0], local.assumed_role_parts[1]), "__TEMPORARY_DIVIDER__", "/") : data.aws_caller_identity.current.arn

  # include current user as EKS admin
  eks_admin_arns = distinct(compact(concat(
    var.eks_admin_arns,
    [local.caller_arn]
  )))
}
