# Front Door Standard + private container; profile MI has Storage Blob Data Reader on the account.

locals {
  fd_profile_name = "${replace(var.workspace, "-", "")}afd"
  fd_endpoint_name = "${replace(var.workspace, "-", "")}cdnep"
}

resource "azurerm_cdn_frontdoor_profile" "cdn" {
  name                = substr(local.fd_profile_name, 0, 80)
  resource_group_name = var.resource_group.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "afd_blob_data_reader" {
  scope                = azurerm_storage_account.blob.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_cdn_frontdoor_profile.cdn.identity[0].principal_id
}

resource "azurerm_cdn_frontdoor_endpoint" "cdn" {
  name                     = substr(local.fd_endpoint_name, 0, 46)
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.cdn.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "cdn" {
  name                     = "${substr(replace(var.workspace, "-", ""), 0, 20)}cdnog"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.cdn.id
  session_affinity_enabled   = false

  health_probe {
    interval_in_seconds = 120
    path                = "/${azurerm_storage_container.cdn.name}"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "blob" {
  name                          = "${substr(replace(var.workspace, "-", ""), 0, 16)}blob"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.cdn.id
  enabled                       = true
  certificate_name_check_enabled = true
  host_name                     = azurerm_storage_account.blob.primary_blob_host
  origin_host_header            = azurerm_storage_account.blob.primary_blob_host
  priority                      = 1
  weight                        = 100
}

resource "azurerm_cdn_frontdoor_route" "cdn" {
  name                          = "${substr(replace(var.workspace, "-", ""), 0, 16)}cdnrte"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.cdn.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.cdn.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.blob.id]

  patterns_to_match   = ["/*"]
  supported_protocols = ["Http", "Https"]

  forwarding_protocol     = "HttpsOnly"
  https_redirect_enabled    = true
  link_to_default_domain    = true
  cdn_frontdoor_origin_path = "/${azurerm_storage_container.cdn.name}"

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/css", "text/javascript", "application/javascript", "application/json"]
  }

  depends_on = [
    azurerm_role_assignment.afd_blob_data_reader,
  ]
}
