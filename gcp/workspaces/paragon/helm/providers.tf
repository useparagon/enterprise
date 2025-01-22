terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.12.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.17.0"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster.host
    token                  = local.cluster.token
    cluster_ca_certificate = local.cluster.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host                   = local.cluster.host
  token                  = local.cluster.token
  cluster_ca_certificate = local.cluster.cluster_ca_certificate
}

provider "kubectl" {
  host                   = local.cluster.host
  token                  = local.cluster.token
  cluster_ca_certificate = local.cluster.cluster_ca_certificate
  load_config_file       = false
}
