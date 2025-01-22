output "redis" {
  value = {
    for key, value in local.redis_instances :
    key => {
      host    = azurerm_redis_cache.redis[key].hostname # azurerm_private_endpoint.redis[key].private_dns_zone_group[0].name
      port    = azurerm_redis_cache.redis[key].non_ssl_port_enabled ? azurerm_redis_cache.redis[key].port : azurerm_redis_cache.redis[key].ssl_port
      ssl     = !azurerm_redis_cache.redis[key].non_ssl_port_enabled
      cluster = value.cluster
    }
  }
  sensitive = true
}
