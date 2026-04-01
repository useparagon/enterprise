locals {
  external_secret_paragon = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "paragon-secrets"
      namespace = var.destination_namespace
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = var.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "paragon-secrets"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = var.env_secret_name
        }
      }]
    }
  })

  external_secret_docker = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "docker-cfg"
      namespace = var.destination_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = var.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "docker-cfg"
        creationPolicy = "Owner"
        template = {
          type = "kubernetes.io/dockerconfigjson"
          data = {
            ".dockerconfigjson" = "{{ .dockerconfigjson }}"
          }
        }
      }
      data = [{
        secretKey = "dockerconfigjson"
        remoteRef = {
          key = var.docker_cfg_secret_name
        }
      }]
    }
  })

  external_secret_managed_sync = var.managed_sync_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "paragon-managed-sync-secrets"
      namespace = var.destination_namespace
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = var.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "paragon-managed-sync-secrets"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = var.managed_sync_secret_name
        }
      }]
    }
  }) : null

  external_secret_openobserve = var.openobserve_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "openobserve-credentials"
      namespace = var.destination_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = var.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "openobserve-credentials"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = var.openobserve_secret_name
        }
      }]
    }
  }) : null
}
