variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "vpc" {
  description = "The VPC to create resources in."
}

variable "public_subnet" {
  description = "The public subnets within the VPC."
}

variable "private_subnet" {
  description = "The private subnets within the VPC."
}

variable "elasticache_node_type" {
  description = "The ElastiCache node type used for Redis."
  type        = string
}

variable "elasticache_multi_az" {
  description = "Whether or not multi-az is enabled."
  type        = bool
}

variable "elasticache_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}

locals {
  redis_instances = var.elasticache_multiple_instances ? merge({
    cache = {
      cluster = true
      size    = var.elasticache_node_type
    }
    queue = {
      cluster = false
      size    = "cache.t4g.medium"
    }
    system = {
      cluster = false
      size    = "cache.t4g.micro"
    }
    }, var.managed_sync_enabled ? {
    managed_sync = {
      cluster = true
      size    = var.elasticache_node_type
    }
    } : {}) : {
    cache = {
      cluster = false
      size    = var.elasticache_node_type
    }
  }

  # https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/AutoScaling.html
  # only certain families supported
  cache_autoscaling_supports_family = contains(["c7gn", "m5", "m6g", "m7g", "r5", "r6g", "r6gd", "r7g"], element(split(".", lower(var.elasticache_node_type)), 1))
  # only large, xlarge, and 2xlarge supported
  cache_autoscaling_supports_size = contains(["large", "xlarge", "2xlarge"], element(split(".", lower(var.elasticache_node_type)), 2))
  cache_autoscaling_enabled       = var.elasticache_multiple_instances && local.cache_autoscaling_supports_family && local.cache_autoscaling_supports_size

  cache_autoscaling_targets = local.cache_autoscaling_enabled ? merge({
    cache = {
      resource_id = "replication-group/${aws_elasticache_replication_group.redis[0].replication_group_id}"
    }
    }, var.managed_sync_enabled && var.elasticache_multiple_instances ? {
    managed_sync = {
      resource_id = "replication-group/${aws_elasticache_replication_group.redis[1].replication_group_id}"
    }
  } : {}) : {}

  redis_instances_standalone = {
    for key, value in local.redis_instances :
    key => value
    if value.cluster == false
  }

  redis_version = "6.x"
}
