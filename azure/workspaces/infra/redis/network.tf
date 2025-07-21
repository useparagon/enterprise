locals {
  # Filter for Standard SKU instances only (for Private Endpoints)
  standard_redis_instances = {
    for key, value in local.redis_instances : key => value
    if value.sku != "Premium"
  }
}

resource "azurerm_redis_firewall_rule" "private_subnet_access" {
  for_each = local.redis_instances

  name = replace("${var.workspace}-${each.key}-redis-private-access", "-", "_")

  redis_cache_name    = azurerm_redis_cache.redis[each.key].name
  resource_group_name = var.resource_group.name
  start_ip            = cidrhost(var.private_subnet.address_prefixes[0], 0)
  end_ip              = cidrhost(var.private_subnet.address_prefixes[0], -1)
}

resource "azurerm_redis_firewall_rule" "public_subnet_access" {
  for_each = local.redis_instances

  name                = replace("${var.workspace}-${each.key}-redis-public-access", "-", "_")
  redis_cache_name    = azurerm_redis_cache.redis[each.key].name
  resource_group_name = var.resource_group.name
  start_ip            = cidrhost(var.public_subnet.address_prefixes[0], 0)
  end_ip              = cidrhost(var.public_subnet.address_prefixes[0], -1)
}

resource "azurerm_redis_firewall_rule" "redis_subnet_access" {
  for_each = local.redis_instances

  name                = replace("${var.workspace}-${each.key}-redis-self-access", "-", "_")
  redis_cache_name    = azurerm_redis_cache.redis[each.key].name
  resource_group_name = var.resource_group.name
  start_ip            = cidrhost(var.redis_subnet.address_prefixes[0], 0)
  end_ip              = cidrhost(var.redis_subnet.address_prefixes[0], -1)
}

# Private Endpoints for Redis caches (only for Standard SKU)
resource "azurerm_private_endpoint" "redis" {
  for_each = local.standard_redis_instances

  name                = "${var.workspace}-${each.key}-redis-pe"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  subnet_id           = var.private_subnet.id

  private_service_connection {
    name                           = "${var.workspace}-${each.key}-redis-connection"
    private_connection_resource_id = azurerm_redis_cache.redis[each.key].id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, { Name = "${var.workspace}-${each.key}-redis-pe" })
}

# Private DNS Zone for Redis (only needed if we have Standard SKU instances)
resource "azurerm_private_dns_zone" "redis" {
  count               = length(local.standard_redis_instances) > 0 ? 1 : 0
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group.name
  tags                = merge(var.tags, { Name = "${var.workspace}-redis-dns" })
}

# Link Private DNS Zone to VNet (only needed if we have Standard SKU instances)
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  count                 = length(local.standard_redis_instances) > 0 ? 1 : 0
  name                  = "${var.workspace}-redis-dns-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.redis[0].name
  virtual_network_id    = var.virtual_network.id
  tags                  = merge(var.tags, { Name = "${var.workspace}-redis-dns-link" })
}

# DNS A Records for each Standard SKU Redis cache
resource "azurerm_private_dns_a_record" "redis" {
  for_each = local.standard_redis_instances

  name                = azurerm_redis_cache.redis[each.key].name
  zone_name           = azurerm_private_dns_zone.redis[0].name
  resource_group_name = var.resource_group.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.redis[each.key].private_service_connection[0].private_ip_address]

  depends_on = [azurerm_private_endpoint.redis]
}
