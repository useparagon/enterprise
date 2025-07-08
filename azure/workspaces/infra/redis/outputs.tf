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

output "redis_debugging" {
  description = "Redis cache instances"
  value = {
    for key, redis in azurerm_redis_cache.redis : key => {
      id                          = redis.id
      name                        = redis.name
      hostname                    = redis.hostname
      ssl_port                    = redis.ssl_port
      non_ssl_port                = redis.port
      primary_access_key          = redis.primary_access_key
      secondary_access_key        = redis.secondary_access_key
      primary_connection_string   = redis.primary_connection_string
      secondary_connection_string = redis.secondary_connection_string
      private_dns_name            = try(azurerm_private_dns_a_record.redis[key].name, null)
      private_ip_address          = try(azurerm_private_endpoint.redis[key].private_service_connection[0].private_ip_address, null)
      sku                         = local.redis_instances[key].sku
    }
  }
}
