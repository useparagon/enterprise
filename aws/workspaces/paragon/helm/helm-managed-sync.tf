resource "helm_release" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name             = "paragon-managed-sync"
  description      = "Managed Sync"
  repository       = "https://paragon-managed-sync-helm.s3.amazonaws.com"
  chart            = "managed-sync"
  version          = var.managed_sync_version
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes

  values = [
    local.global_values,
    local.secret_hash
  ]

  dynamic "set" {
    for_each = var.microservices

    content {
      name  = "${set.key}.env.SERVICE"
      value = set.key
    }
  }

  # used to set map the ingress to the public url of each microservice
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.common.ingress.host"
      value = replace(replace(set.value.public_url, "https://", ""), "http://", "")
    }
  }

  # configures whether the load balancer is 'internet-facing' (public) or 'internal' (private)
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.common.ingress.scheme"
      value = var.ingress_scheme
    }
  }

  # configures the ssl cert to the load balancer
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.common.ingress.certificate"
      value = var.certificate
    }
  }

  # configures the load balancer name
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.common.ingress.load_balancer_name"
      value = var.workspace
    }
  }

  # configures load balancer bucket for logging
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.common.ingress.logs_bucket"
      value = var.logs_bucket
    }
  }

  depends_on = [
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_secret.paragon_secrets,
    kubernetes_storage_class_v1.gp3_encrypted
  ]
}

resource "helm_release" "managed_sync_openfga" {
  count = var.managed_sync_enabled ? 1 : 0

  name             = "openfga"
  description      = "Managed Sync OpenFGA"
  repository       = "https://openfga.github.io/helm-charts"
  chart            = "openfga"
  version          = "0.2.30"
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true

  set {
    name  = "datastore.engine"
    value = "postgres"
  }

  set {
    name  = "log.format"
    value = "json"
  }

  set_sensitive {
    name  = "datastore.uri"
    value = "postgres://${var.helm_values.global.env.OPENFGA_POSTGRES_USERNAME}:${var.helm_values.global.env.OPENFGA_POSTGRES_PASSWORD}@${var.helm_values.global.env.OPENFGA_POSTGRES_HOST}:${var.helm_values.global.env.OPENFGA_POSTGRES_PORT}/${var.helm_values.global.env.OPENFGA_POSTGRES_DATABASE}?sslmode=required"
  }

  set {
    name  = "authn.preshared.keys[0]"
    value = var.helm_values.global.env.OPENFGA_AUTH_PRESHARED_KEYS
  }

  set {
    name  = "service.port"
    value = var.helm_values.global.env.OPENFGA_HTTP_PORT
  }

  set {
    name  = "http.addr"
    value = "0.0.0.0:${var.helm_values.global.env.OPENFGA_HTTP_PORT}"
  }

  set {
    name  = "grpc.addr"
    value = "0.0.0.0:${var.helm_values.global.env.OPENFGA_GRPC_PORT}"
  }

  set {
    name  = "playground.enabled"
    value = false
  }
}
