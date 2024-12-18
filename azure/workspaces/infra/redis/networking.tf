resource "azurerm_subnet" "redis" {
  name                 = "${var.app_name}-redis-subnet"
  resource_group_name  = var.resource_group.name
  virtual_network_name = var.virtual_network.name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 2, 2)]
}

resource "azurerm_redis_firewall_rule" "private_subnet_access" {
  name = replace("${var.app_name}-private-subnet-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group.name

  start_ip = cidrhost(var.private_subnet.address_prefixes[0], 0)
  end_ip   = cidrhost(var.private_subnet.address_prefixes[0], -1)
}

resource "azurerm_redis_firewall_rule" "public_subnet_access" {
  name = replace("${var.app_name}-public-subnet-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group.name

  start_ip = cidrhost(var.public_subnet.address_prefixes[0], 0)
  end_ip   = cidrhost(var.public_subnet.address_prefixes[0], -1)
}

resource "azurerm_redis_firewall_rule" "redis_subnet_access" {
  name = replace("${var.app_name}-redis-subnet-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.resource_group.name

  start_ip = cidrhost(azurerm_subnet.redis.address_prefixes[0], 0)
  end_ip   = cidrhost(azurerm_subnet.redis.address_prefixes[0], -1)
}
