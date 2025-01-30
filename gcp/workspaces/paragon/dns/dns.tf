data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

locals {
  is_ip = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.ingress_loadbalancer))
}

resource "cloudflare_record" "cname" {
  for_each = var.public_services

  # strip protocol and domain from URL to get subdomain
  name = replace(replace(each.value.public_url, "https://", ""), ".${data.cloudflare_zone.zone.name}", "")

  content = var.ingress_loadbalancer
  ttl     = 600
  type    = local.is_ip ? "A" : "CNAME"
  zone_id = var.cloudflare_zone_id
}
