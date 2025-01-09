data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_record" "cname" {
  for_each = var.public_services

  # strip protocol and domain from URL to get subdomain
  name = replace(replace(each.value.public_url, "https://", ""), ".${data.cloudflare_zone.zone.name}", "")

  content = var.ingress_loadbalancer
  ttl     = 600
  type    = "CNAME"
  zone_id = var.cloudflare_zone_id
}
