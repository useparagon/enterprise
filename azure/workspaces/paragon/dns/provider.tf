terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.42"
    }
  }
}

provider "cloudflare" {
  api_token = var.enabled ? var.cloudflare_api_token : "placeholder_0apiTokencloudflareonprem100"
}
