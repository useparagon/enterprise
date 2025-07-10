output "redis" {
  value = {
    for key, value in local.redis_instances :
    key => {
      # Use Private Endpoint DNS names for Standard SKU, regular hostname for Premium SKU
      host              = value.sku == "Premium" ? azurerm_redis_cache.redis[key].hostname : try(trim(azurerm_private_dns_a_record.redis[key].fqdn, "."), azurerm_redis_cache.redis[key].hostname)
      port              = azurerm_redis_cache.redis[key].non_ssl_port_enabled ? azurerm_redis_cache.redis[key].port : azurerm_redis_cache.redis[key].ssl_port
      password          = azurerm_redis_cache.redis[key].primary_access_key
      ssl               = !azurerm_redis_cache.redis[key].non_ssl_port_enabled
      cluster           = value.cluster && value.sku == "Premium"
      connection_string = ":${azurerm_redis_cache.redis[key].primary_access_key}@${value.sku == "Premium" ? azurerm_redis_cache.redis[key].hostname : try(trim(azurerm_private_dns_a_record.redis[key].fqdn, "."), azurerm_redis_cache.redis[key].hostname)}:${azurerm_redis_cache.redis[key].non_ssl_port_enabled ? azurerm_redis_cache.redis[key].port : azurerm_redis_cache.redis[key].ssl_port}"
    }
  }
  sensitive = true
}
