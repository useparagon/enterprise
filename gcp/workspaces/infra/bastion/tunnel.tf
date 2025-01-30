# Generates a 35-character secret for the tunnel.
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

data "cloudflare_zone" "zone" {
  count = var.cloudflare_tunnel_enabled ? 1 : 0

  zone_id = var.cloudflare_tunnel_zone_id
}

locals {
  tunnel_domain = var.cloudflare_tunnel_enabled ? "${var.cloudflare_tunnel_subdomain}.${data.cloudflare_zone.zone[0].name}" : ""
  tunnel_secret = random_id.tunnel_secret.b64_std
}

# Creates a new locally-managed tunnel for the bastion
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  count = var.cloudflare_tunnel_enabled ? 1 : 0

  account_id = var.cloudflare_tunnel_account_id
  name       = local.tunnel_domain
  secret     = local.tunnel_secret

  lifecycle {
    precondition {
      condition     = !var.cloudflare_tunnel_enabled || (length(var.cloudflare_api_token) > 0 && length(var.cloudflare_tunnel_subdomain) > 0 && length(var.cloudflare_tunnel_zone_id) > 0 && length(var.cloudflare_tunnel_account_id) > 0 && length(var.cloudflare_tunnel_email_domain) > 0)
      error_message = "cloudflare_api_token, cloudflare_tunnel_account_id, cloudflare_tunnel_email_domain, cloudflare_tunnel_subdomain and cloudflare_tunnel_zone_id are required when cloudflare_tunnel_enabled"
    }
  }
}

locals {
  tunnel_id = var.cloudflare_tunnel_enabled ? cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id : ""
}

# Creates the CNAME record that routes domain to the tunnel
resource "cloudflare_record" "tunnel" {
  count = var.cloudflare_tunnel_enabled ? 1 : 0

  zone_id = var.cloudflare_tunnel_zone_id
  name    = var.cloudflare_tunnel_subdomain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# Creates an Access application to control who can connect
resource "cloudflare_zero_trust_access_application" "tunnel" {
  count = var.cloudflare_tunnel_enabled ? 1 : 0

  zone_id          = var.cloudflare_tunnel_zone_id
  name             = local.tunnel_domain
  domain           = local.tunnel_domain
  session_duration = "1h"
}

# Creates an Access group for the application
resource "cloudflare_zero_trust_access_group" "tunnel" {
  count = var.cloudflare_tunnel_enabled ? 1 : 0

  zone_id = var.cloudflare_tunnel_zone_id
  name    = local.tunnel_domain

  include {
    email_domain = [var.cloudflare_tunnel_email_domain]
  }
}

# Creates an Access policy for the application
resource "cloudflare_zero_trust_access_policy" "tunnel" {
  count = var.cloudflare_tunnel_enabled ? 1 : 0

  application_id = cloudflare_zero_trust_access_application.tunnel[0].id
  zone_id        = var.cloudflare_tunnel_zone_id
  name           = local.tunnel_domain
  decision       = "allow"
  precedence     = "1"

  include {
    group = cloudflare_zero_trust_access_group.tunnel.*.id
  }
}
