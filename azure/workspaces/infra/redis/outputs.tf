output "redis" {
  value = {
    cache = {
      host    = azurerm_redis_cache.redis.hostname
      port    = azurerm_redis_cache.redis.non_ssl_port_enabled ? azurerm_redis_cache.redis.port : azurerm_redis_cache.redis.ssl_port
      cluster = (azurerm_redis_cache.redis.replicas_per_master + azurerm_redis_cache.redis.replicas_per_primary + azurerm_redis_cache.redis.shard_count) > 0
      ssl     = !azurerm_redis_cache.redis.non_ssl_port_enabled
    }
  }
  sensitive = true
}
