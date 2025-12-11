resource "helm_release" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name             = "paragon-managed-sync"
  description      = "Managed Sync"
  repository       = "https://paragon-helm-production.s3.amazonaws.com"
  chart            = "managed-sync"
  version          = var.managed_sync_version
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 600 # 10 minutes

  values = [
    local.global_values_minus_env,
    local.public_microservice_values,
    local.secret_hash
  ]

  set {
    name  = "ingress.host"
    value = replace(replace(var.microservices["api-sync"].public_url, "https://", ""), "http://", "")
  }

  set {
    name  = "ingress.class"
    value = "nginx"
  }

  set {
    name  = "ingress.className"
    value = "nginx"
  }

  set {
    name  = "ingress.loadBalancerName"
    value = var.workspace
  }

  depends_on = [
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_secret.paragon_secrets
  ]
}
