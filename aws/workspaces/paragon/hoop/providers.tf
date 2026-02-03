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
