output "redis" {
  value = {
    host   = azurerm_redis_cache.redis.primary_connection_string
    port   = azurerm_redis_cache.redis.port
    k8host = split(":", azurerm_redis_cache.redis.primary_connection_string)[0]
  }
}
