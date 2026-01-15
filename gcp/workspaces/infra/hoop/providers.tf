terraform {
  required_providers {
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
  }
}

provider "kubernetes" {
  host                   = var.cluster_host
  token                  = var.cluster_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_host
    token                  = var.cluster_token
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}
