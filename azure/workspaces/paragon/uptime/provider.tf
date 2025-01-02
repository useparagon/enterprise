terraform {
  required_providers {
    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "~> 0.11.5"
    }
  }
}

provider "betteruptime" {
  api_token = coalesce(var.uptime_api_token, "dummy-token")
}
