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

data "aws_eks_cluster_auth" "cluster" {
  name = var.workspace
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  }
}
