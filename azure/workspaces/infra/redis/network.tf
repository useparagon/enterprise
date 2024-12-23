resource "azurerm_redis_firewall_rule" "private_subnet_access" {
  name = replace("${var.workspace}-redis-private-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group.name

  start_ip = cidrhost(var.private_subnet.address_prefixes[0], 0)
  end_ip   = cidrhost(var.private_subnet.address_prefixes[0], -1)
}

resource "azurerm_redis_firewall_rule" "public_subnet_access" {
  name = replace("${var.workspace}-redis-public-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group.name

  start_ip = cidrhost(var.public_subnet.address_prefixes[0], 0)
  end_ip   = cidrhost(var.public_subnet.address_prefixes[0], -1)
}

resource "azurerm_redis_firewall_rule" "redis_subnet_access" {
  name = replace("${var.workspace}-redis-self-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group.name

  start_ip = cidrhost(var.redis_subnet.address_prefixes[0], 0)
  end_ip   = cidrhost(var.redis_subnet.address_prefixes[0], -1)
}
