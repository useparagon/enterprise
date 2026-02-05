resource "azurerm_key_vault" "paragon" {
  name                = substr(var.workspace, 0, 24)
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
}

resource "azurerm_key_vault_access_policy" "aks_access_to_kv" {
  key_vault_id = azurerm_key_vault.paragon.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_kubernetes_cluster.cluster.kubelet_identity.0.object_id

  certificate_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace_v1.paragon.id
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"

  force_update     = false
  create_namespace = false

  set {
    name  = "installCRDs"
    value = true
  }
}

# ingress controller
resource "azurerm_public_ip" "ingress" {
  count = var.ingress_scheme == "internal" ? 0 : 1

  name                = "AKS-Ingress-Controller"
  allocation_method   = "Static"
  domain_name_label   = var.workspace
  location            = var.resource_group.location
  resource_group_name = data.azurerm_kubernetes_cluster.cluster.node_resource_group
  sku                 = "Standard"
}

resource "helm_release" "ingress" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.paragon.id
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  dynamic "set" {
    for_each = var.ingress_scheme == "internal" ? [] : [1]
    content {
      name  = "controller.service.loadBalancerIP"
      value = azurerm_public_ip.ingress[0].ip_address
    }
  }

  dynamic "set" {
    for_each = var.ingress_scheme == "internal" ? [1] : []
    content {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
      value = "true"
    }
  }

  set {
    name  = "controller.service.annotations.service\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_kubernetes_cluster.cluster.node_resource_group
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  set {
    name  = "controller.config.proxy-buffers-number"
    value = "8"
  }

  set {
    name  = "controller.config.proxy-buffer-size"
    value = "16k"
  }

  depends_on = [
    helm_release.cert_manager,
    azurerm_key_vault_access_policy.aks_access_to_kv,
    azurerm_public_ip.ingress
  ]
}

resource "time_sleep" "wait" {
  create_duration = "60s"

  depends_on = [helm_release.ingress]
}

resource "kubectl_manifest" "certificate_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: ${kubernetes_namespace_v1.paragon.id}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: enterprise@useparagon.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
YAML

  depends_on = [
    helm_release.cert_manager,
    time_sleep.wait
  ]
}
