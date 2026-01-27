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
    hoop = {
      source  = "hoophq/hoop"
      version = ">= 0.0.19"
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  }
}

provider "hoop" {
  api_url = var.hoop_api_url
  # Always use a valid API key so Terraform can read/destroy resources when hoop_enabled is set to false.
  # If api_key is null, provider will read from HOOP_APIKEY environment variable.
  api_key = var.hoop_api_key
}
