data "cloudflare_zone" "zone" {
  count   = var.enabled ? 1 : 0
  zone_id = var.cloudflare_zone_id
}

locals {
  is_ip    = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.ingress_loadbalancer))
  zone     = var.enabled ? data.cloudflare_zone.zone[0].name : ""
  wildcard = var.domain == local.zone ? "*" : "*.${replace(var.domain, ".${local.zone}", "")}"
}

resource "cloudflare_record" "dns" {
  count = var.enabled ? 1 : 0

  name    = local.wildcard
  content = var.ingress_loadbalancer
  ttl     = 600
  type    = local.is_ip ? "A" : "CNAME"
  zone_id = var.cloudflare_zone_id
}
