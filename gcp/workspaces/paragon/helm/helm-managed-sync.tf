# Managed Sync (when enabled) — GCP. Same strategy as AWS: values = [ global_values_minus_env, secret_hash ].
# global_values_minus_env comes from var.helm_values (paragon workspace merges .secure/values.yaml via helm_yaml_path into helm_values).
# Env vars: helm-config managed_sync_secrets → Secret paragon-managed-sync-secrets.
# TEMPORARY: sandbox bucket; production uses paragon-helm-production.

resource "helm_release" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name             = "paragon-managed-sync"
  namespace        = kubernetes_namespace_v1.paragon.id
  repository       = "https://managed-sync-helm-sandbox.s3.amazonaws.com"
  chart            = "managed-sync"
  version          = var.managed_sync_version
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 300
  force_update     = true

  values = [
    local.global_values_minus_env,
    local.secret_hash
  ]

  set {
    name  = "secretName"
    value = "paragon-managed-sync-secrets"
  }

  set {
    name  = "ingress.certificate"
    value = google_compute_managed_ssl_certificate.cert.name
  }

  set {
    name  = "ingress.className"
    value = "gce"
  }

  set {
    name  = "ingress.frontendConfig"
    value = google_compute_region_url_map.frontend_config.name
  }

  set {
    name  = "ingress.healthCheckPath"
    value = "/healthz"
  }

  set {
    name  = "ingress.host"
    value = replace(replace(try(var.microservices["api-sync"].public_url, "https://sync.${var.domain}"), "https://", ""), "http://", "")
  }

  set {
    name  = "ingress.loadBalancerName"
    value = google_compute_global_address.loadbalancer.name
  }

  set {
    name  = "ingress.logsBucket"
    value = var.logs_bucket
  }

  set {
    name  = "ingress.listenPorts[0].HTTP"
    value = "80"
  }

  set {
    name  = "ingress.listenPorts[1].HTTPS"
    value = "443"
  }

  set {
    name  = "ingress.scheme"
    value = var.ingress_scheme
  }

  depends_on = [
    google_compute_managed_ssl_certificate.cert,
    google_compute_global_address.loadbalancer,
    google_compute_region_url_map.frontend_config,
    kubernetes_secret_v1.docker_login,
    kubernetes_secret_v1.paragon_secrets,
  ]
}
