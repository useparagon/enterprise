terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_dns_api_token != null ? var.cloudflare_dns_api_token : "placeholder_0apiTokencloudflareonprem100"
}
