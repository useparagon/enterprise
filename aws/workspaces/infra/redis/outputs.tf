output "elasticache" {
  value = var.elasticache_multiple_instances ? {
    for key, value in local.redis_instances :
    key => key == "cache" ? {
      host    = aws_elasticache_replication_group.redis[0].configuration_endpoint_address
      port    = 6379
      cluster = value.cluster
      } : {
      host    = aws_elasticache_cluster.redis[key].cache_nodes[0].address
      port    = aws_elasticache_cluster.redis[key].cache_nodes[0].port
      cluster = value.cluster
    }
    } : {
    cache = {
      host    = aws_elasticache_cluster.redis["cache"].cache_nodes[0].address
      port    = aws_elasticache_cluster.redis["cache"].cache_nodes[0].port
      cluster = false
    }
  }
  sensitive = true
}
