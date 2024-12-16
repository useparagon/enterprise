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

variable "eks_k8s_version" {
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
      version = "v1.37.0-eksbuild.1"
    }
    coredns = {
      version = "v1.11.3-eksbuild.1"
    }
    kube-proxy = {
      version = "v1.31.0-eksbuild.2"
    }
    vpc-cni = {
      version = "v1.18.3-eksbuild.2"
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

  # include current user as EKS admin
  eks_admin_arns = distinct(compact(concat(
    var.eks_admin_arns,
    [data.aws_caller_identity.current.arn]
  )))
}
