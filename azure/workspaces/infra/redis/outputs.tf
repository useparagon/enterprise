output "redis" {
  value = {
    cache = {
      host              = split(":", azurerm_redis_cache.redis.primary_connection_string)[0]
      port              = azurerm_redis_cache.redis.port
      cluster           = false
      connection_string = azurerm_redis_cache.redis.primary_connection_string
    }
  }
  sensitive = true
}
