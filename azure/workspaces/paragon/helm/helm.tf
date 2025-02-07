locals {
  subchart_values = yamlencode({
    subchart = {
      for microservice in keys(var.microservices) : microservice => {
        enabled = true
      }
    }
  })

  microservice_values = yamlencode({
    for microservice_name, microservice_config in var.microservices : microservice_name => {
      env = {
        SERVICE = microservice_name
      }
    }
  })

  public_microservice_values = yamlencode({
    for microservice_name, microservice_config in var.public_microservices : microservice_name => {
      ingress = {
        className = "nginx"
        host      = replace(replace(microservice_config.public_url, "https://", ""), "http://", "")
        annotations = {
          "kubernetes.io/ingress.class"    = "nginx"
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        scheme = var.ingress_scheme
      }
      tls_secret = "${microservice_name}-secret"
    }
  })

  monitor_values = yamlencode({
    for monitor_name, monitor_config in var.monitors : monitor_name => {
      image = {
        tag = var.monitor_version
      }
    }
  })

  public_monitor_values = yamlencode({
    for monitor_name, monitor_config in var.public_monitors : monitor_name => {
      ingress = {
        className = "nginx"
        host      = replace(replace(monitor_config.public_url, "https://", ""), "http://", "")
        annotations = {
          "kubernetes.io/ingress.class"    = "nginx"
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        scheme = var.ingress_scheme
      }
      tls_secret = "${monitor_name}-secret"
    }
  })

  global_values = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global = merge(
        nonsensitive(var.helm_values.global),
        {
          env = {
            HOST_ENV    = "AZURE_K8"
            k8s_version = var.k8s_version
            secretName  = "paragon-secrets"
          },
          paragon_version = var.helm_values.global.env["VERSION"]
        }
      )
    }
  ))

  # changes to secrets should trigger redeploy
  secret_hash = yamlencode({
    secret_hash = sha256(jsonencode(nonsensitive(var.helm_values.global.env)))
  })
}

# creates the `paragon` namespace
resource "kubernetes_namespace" "paragon" {
  metadata {
    name = "paragon"

    annotations = {
      name = "paragon"
    }
  }
}

# kubernetes secret to pull docker image from docker hub
resource "kubernetes_secret" "docker_login" {
  metadata {
    name      = "docker-cfg"
    namespace = kubernetes_namespace.paragon.id
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.docker_registry_server}" = {
          "username" = var.docker_username
          "password" = var.docker_password
          "email"    = var.docker_email
          "auth"     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  }
}

# shared secrets
resource "kubernetes_secret" "paragon_secrets" {
  metadata {
    name      = "paragon-secrets"
    namespace = kubernetes_namespace.paragon.id
  }

  type = "Opaque"

  data = {
    # Map global.env from helm_values into secret data
    for key, value in nonsensitive(var.helm_values.global.env) :
    key => value
  }
}

# microservices deployment
resource "helm_release" "paragon_on_prem" {
  name             = "paragon-on-prem"
  description      = "Paragon microservices"
  chart            = "./charts/paragon-onprem"
  version          = "${var.helm_values.global.env["VERSION"]}-${local.chart_hashes["paragon-onprem"]}"
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes

  values = [
    local.subchart_values,
    local.global_values,
    local.microservice_values,
    local.public_microservice_values,
    local.secret_hash
  ]

  depends_on = [
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_secret.paragon_secrets,
    kubernetes_secret.microservices
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name             = "paragon-logging"
  description      = "Paragon logging services"
  chart            = "./charts/paragon-logging"
  version          = "${var.helm_values.global.env["VERSION"]}-${local.chart_hashes["paragon-logging"]}"
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes

  values = [
    local.global_values
  ]

  set {
    name  = "global.env.ZO_S3_PROVIDER"
    value = "azure"
  }

  set {
    name  = "global.env.ZO_S3_BUCKET_NAME"
    value = var.logs_bucket
  }

  set {
    name  = "global.env.ZO_ROOT_USER_EMAIL"
    value = local.openobserve_email
  }

  set_sensitive {
    name  = "global.env.ZO_ROOT_USER_PASSWORD"
    value = local.openobserve_password
  }

  depends_on = [
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_secret.microservices
  ]
}

# monitors deployment
resource "helm_release" "paragon_monitoring" {
  count = var.monitors_enabled ? 1 : 0

  name             = "paragon-monitoring"
  description      = "Paragon monitors"
  chart            = "./charts/paragon-monitoring"
  version          = "${var.monitor_version}-${local.chart_hashes["paragon-monitoring"]}"
  namespace        = "paragon"
  cleanup_on_fail  = true
  create_namespace = false
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes

  values = [
    local.global_values,
    local.monitor_values,
    local.public_monitor_values,
    local.secret_hash
  ]

  # used to load environment variables into microservices
  dynamic "set_sensitive" {
    for_each = nonsensitive(merge(var.helm_values.global.env))
    content {
      name  = "global.env.${set_sensitive.key}"
      value = set_sensitive.value
    }
  }

  depends_on = [
    helm_release.ingress,
    helm_release.paragon_on_prem,
    kubernetes_secret.docker_login,
    kubernetes_secret.microservices
  ]
}
