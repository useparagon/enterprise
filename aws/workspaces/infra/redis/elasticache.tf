# not every instance type is available within each AZ so filter AZs to just those with desired node type
data "aws_ec2_instance_type_offerings" "cache_filter" {
  filter {
    name   = "instance-type"
    values = [substr(local.redis_instances.cache.size, 6, -1)] # strip "cache." to filter
  }
  filter {
    name   = "location"
    values = var.private_subnet.*.availability_zone
  }
  location_type = "availability-zone"
}

# then filter subnets to just those filtered AZs
locals {
  cache_subnet_ids = [for each in var.private_subnet : each.id if contains(data.aws_ec2_instance_type_offerings.cache_filter.locations, each.availability_zone)]
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.workspace}-elasticache-subnet"
  subnet_ids = local.cache_subnet_ids
}

resource "aws_elasticache_parameter_group" "redis" {
  for_each = toset(["cluster", "standalone"])

  name   = "${var.workspace}-redis-${each.key}${substr(local.redis_version, 0, 1)}"
  family = "redis${local.redis_version}"

  # when max memory is reached, the eviction policy is to remove the least-recently-used keys
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  # how often, in seconds, clients are pinged to ensure they're still connected
  parameter {
    name  = "tcp-keepalive"
    value = "30"
  }

  # number of seconds nodes wait before disconnecting idle clients
  parameter {
    name  = "timeout"
    value = "120"
  }

  # whether or not cluster is enabled
  parameter {
    name  = "cluster-enabled"
    value = each.key == "cluster" ? "yes" : "no"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-redis${local.redis_version}-${each.key}"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count = var.elasticache_multiple_instances ? (var.managed_sync_enabled ? 2 : 1) : 0

  replication_group_id = "${var.workspace}-redis-${count.index == 1 ? "cache" : "managed-sync"}"
  description          = "Redis cluster for caching & workflows."
  apply_immediately    = true
  node_type            = local.redis_instances.cache.size
  engine_version       = local.redis_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis["cluster"].name

  snapshot_retention_limit = 5
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"

  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.elasticache.id]
  multi_az_enabled           = var.elasticache_multi_az
  automatic_failover_enabled = true
  num_node_groups            = 1
  replicas_per_node_group    = var.elasticache_multi_az ? 1 : 0

  # don't let terraform undo any autoscaling
  lifecycle {
    ignore_changes = [num_node_groups]
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${var.workspace}-redis-${count.index == 1 ? "cache" : "managed-sync"}"
    Cluster = "true"
  }
}

resource "aws_elasticache_cluster" "redis" {
  for_each = local.redis_instances_standalone

  cluster_id           = var.elasticache_multiple_instances ? "${var.workspace}-redis-${each.key}" : "${var.workspace}-redis"
  engine               = "redis"
  node_type            = each.value.size
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis["standalone"].name
  engine_version       = local.redis_version
  port                 = 6379
  apply_immediately    = true

  snapshot_retention_limit = 5
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"
  subnet_group_name        = aws_elasticache_subnet_group.main.name
  security_group_ids       = [aws_security_group.elasticache.id]

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${var.workspace}-redis-${each.key}"
    Cluster = "false"
  }
}

resource "aws_cloudwatch_log_group" "redis" {
  name_prefix       = "${var.workspace}-redis"
  retention_in_days = 365
}

resource "aws_appautoscaling_target" "cache" {
  for_each = local.cache_autoscaling_targets

  resource_id        = each.value.resource_id
  service_namespace  = "elasticache"
  scalable_dimension = "elasticache:replication-group:NodeGroups"
  min_capacity       = 1
  max_capacity       = 10
}

resource "aws_appautoscaling_policy" "cache_memory" {
  for_each = local.cache_autoscaling_targets

  resource_id        = aws_appautoscaling_target.cache[each.key].resource_id
  service_namespace  = aws_appautoscaling_target.cache[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.cache[each.key].scalable_dimension
  name               = "${var.workspace}-redis-cache-autoscaling-memory-${each.key}"
  policy_type        = "TargetTrackingScaling"

  # adjust the number of nodes up or down to try to keep memory usage at target_value
  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 600
    scale_out_cooldown = 600

    predefined_metric_specification {
      predefined_metric_type = "ElastiCacheDatabaseMemoryUsageCountedForEvictPercentage"
    }
  }
}

resource "aws_appautoscaling_policy" "cache_cpu" {
  for_each = local.cache_autoscaling_targets

  resource_id        = aws_appautoscaling_target.cache[each.key].resource_id
  service_namespace  = aws_appautoscaling_target.cache[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.cache[each.key].scalable_dimension
  name               = "${var.workspace}-redis-cache-autoscaling-cpu-${each.key}"
  policy_type        = "TargetTrackingScaling"

  # adjust the number of nodes up or down to try to keep cpu usage at target_value
  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 600
    scale_out_cooldown = 600

    predefined_metric_specification {
      predefined_metric_type = "ElastiCachePrimaryEngineCPUUtilization"
    }
  }
}
