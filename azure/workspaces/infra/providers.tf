provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  features {}
}

provider "azuread" {
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id     = var.azure_tenant_id
}

# provider "acme" {
#   server_url = "https://acme-v02.api.letsencrypt.org/directory"
# }
