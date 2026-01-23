terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    hoop = {
      source  = "hoophq/hoop"
      version = ">= 0.0.19"
    }
  }
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
  username               = data.azurerm_kubernetes_cluster.cluster.kube_config.0.username
  password               = data.azurerm_kubernetes_cluster.cluster.kube_config.0.password
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
    username               = data.azurerm_kubernetes_cluster.cluster.kube_config.0.username
    password               = data.azurerm_kubernetes_cluster.cluster.kube_config.0.password
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
  }
}

provider "hoop" {
  api_url = var.hoop_api_url
  # If api_key is null, provider will read from HOOP_APIKEY environment variable
  api_key = var.hoop_enabled ? var.hoop_api_key : "disabled"
}
