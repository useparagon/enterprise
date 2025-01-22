resource "kubernetes_secret" "microservices" {
  for_each = var.microservices

  metadata {
    name      = "${each.key}-secret"
    namespace = kubernetes_namespace.paragon.id
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.paragon.id
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
resource "google_compute_address" "loadbalancer" {
  name = "${var.workspace}-ingress"
}

resource "helm_release" "ingress" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.paragon.id
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"

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

  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.loadbalancer.address
  }

  set {
    name  = "rbac.create"
    value = true
  }

  set {
    name  = "podSecurityPolicy.enabled"
    value = true
  }

  set {
    name  = "controller.publishService.enabled"
    value = true
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
    kubernetes_secret.microservices,
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
  namespace: ${kubernetes_namespace.paragon.id}
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
