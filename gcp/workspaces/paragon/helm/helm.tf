locals {
  namespace = "paragon"

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
        enabled = false
        # values below would only be needed if per service load balancers are desired
        # certificate      = google_compute_managed_ssl_certificate.cert.name
        # className        = var.ingress_scheme == "internal" ? "gce-internal" : "gce"
        # host             = replace(microservice_config.public_url, "https://", "")
        # frontendConfig   = google_compute_region_url_map.frontend_config.name
        # loadBalancerIP   = google_compute_global_address.loadbalancer.address
        # loadBalancerName = google_compute_global_address.loadbalancer.name
        # scheme           = var.ingress_scheme
      }
      service = {
        type = "NodePort"
      }
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
        enabled = false
        # values below would only be needed if per service load balancers are desired
        # certificate      = google_compute_managed_ssl_certificate.cert.name
        # className        = var.ingress_scheme == "internal" ? "gce-internal" : "gce"
        # host             = replace(replace(monitor_config.public_url, "https://", ""), "http://", "")
        # frontendConfig   = google_compute_region_url_map.frontend_config.name
        # loadBalancerIP   = google_compute_global_address.loadbalancer.address
        # loadBalancerName = google_compute_global_address.loadbalancer.name
        # scheme           = var.ingress_scheme
      }
      service = merge(
        {
          type = "NodePort"
        },
        monitor_name == "grafana" ? {
          annotations = {
            "cloud.google.com/backend-config" = jsonencode({
              default = "grafana-backendconfig"
            })
          }
        } : {}
      )
    }
  })

  flipt_values = yamlencode({
    flipt = {
      flipt = {
        extraEnvVars = [
          for k, v in var.flipt_options : {
            name  = k
            value = v
          }
        ]
        persistence = var.feature_flags_content != null ? {
          enabled = true
        } : {}
        extraVolumes = var.feature_flags_content != null ? [
          {
            name = "feature-flags-content"
            configMap = {
              name = kubernetes_config_map_v1.feature_flag_content[0].metadata[0].name
            }
          }
        ] : []
        extraVolumeMounts = var.feature_flags_content != null ? [
          {
            name      = "feature-flags-content"
            mountPath = "/var/opt/flipt/production/features.yml"
            subPath   = "features.yml"
            readOnly  = true
          }
        ] : []
      }
    }
  })

  cloud_storage_services = [
    "api-triggerkit",
    "cache-replay",
    "hades",
    "health-checker",
    "hermes",
    "openobserve",
    "release",
    "worker-actionkit",
    "worker-actions",
    "worker-credentials",
    "worker-crons",
    "worker-deployments",
    "worker-proxy",
    "worker-triggers",
    "worker-triggerkit",
    "worker-workflows",
    "zeus"
  ]

  service_account_values = var.storage_service_account != null ? {
    for service_name in local.cloud_storage_services : service_name => {
      serviceAccount = {
        create = true
        annotations = {
          "iam.gke.io/gcp-service-account" = var.storage_service_account
        }
      }
    }
  } : {}

  global_values = yamlencode(merge(
    nonsensitive(var.helm_values),
    local.service_account_values,
    {
      global = merge(
        nonsensitive(var.helm_values.global),
        {
          env = merge(
            nonsensitive(var.helm_values.global.env),
            {
              k8s_version = var.k8s_version
              secretName  = "paragon-secrets"
            }
          ),
          paragon_version = var.helm_values.global.env["VERSION"]
        }
      )
    }
  ))

  # changes to secrets should trigger redeploy
  secret_hash = yamlencode({
    secret_hash = sha256(jsonencode(nonsensitive(var.helm_values)))
  })
}

# creates the `paragon` namespace
resource "kubernetes_namespace_v1" "paragon" {
  metadata {
    name = "paragon"

    annotations = {
      name = "paragon"
    }
  }
}

resource "kubernetes_config_map_v1" "feature_flag_content" {
  count = var.feature_flags_content != null ? 1 : 0

  metadata {
    name      = "feature-flags-content"
    namespace = kubernetes_namespace_v1.paragon.id
  }

  data = {
    "features.yml" = var.feature_flags_content
  }
}

# kubernetes secret to pull docker image from docker hub
resource "kubernetes_secret_v1" "docker_login" {
  metadata {
    name      = "docker-cfg"
    namespace = kubernetes_namespace_v1.paragon.id
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
resource "kubernetes_secret_v1" "paragon_secrets" {
  metadata {
    name      = "paragon-secrets"
    namespace = kubernetes_namespace_v1.paragon.id
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
  namespace        = kubernetes_namespace_v1.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes
  dependency_update = true

  values = [
    local.subchart_values,
    local.global_values,
    local.flipt_values,
    local.microservice_values,
    local.public_microservice_values,
    local.secret_hash
  ]

  depends_on = [
    kubernetes_secret_v1.docker_login,
    kubernetes_secret_v1.paragon_secrets,
    kubernetes_config_map_v1.feature_flag_content
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name             = "paragon-logging"
  description      = "Paragon logging services"
  chart            = "./charts/paragon-logging"
  version          = "${var.helm_values.global.env["VERSION"]}-${local.chart_hashes["paragon-logging"]}"
  namespace        = kubernetes_namespace_v1.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes
  dependency_update = true

  values = fileexists("${path.root}/../.secure/values.yaml") ? [
    local.global_values,
    file("${path.root}/../.secure/values.yaml")
    ] : [
    local.global_values
  ]

  set_sensitive {
    name  = "fluent-bit.secrets.ZO_ROOT_USER_EMAIL"
    value = local.openobserve_email
  }

  set_sensitive {
    name  = "fluent-bit.secrets.ZO_ROOT_USER_PASSWORD"
    value = local.openobserve_password
  }

  set_sensitive {
    name  = "openobserve.secrets.ZO_ROOT_USER_EMAIL"
    value = local.openobserve_email
  }

  set_sensitive {
    name  = "openobserve.secrets.ZO_ROOT_USER_PASSWORD"
    value = local.openobserve_password
  }

  dynamic "set_sensitive" {
    for_each = var.gcp_creds != null ? [1] : []
    content {
      name  = "openobserve.credsJson"
      value = base64encode(var.gcp_creds)
    }
  }

  set {
    name  = "openobserve.env.ZO_S3_BUCKET_NAME"
    value = var.logs_bucket
  }

  set {
    name  = "openobserve.env.ZO_S3_REGION_NAME"
    value = var.region
  }

  dynamic "set_sensitive" {
    for_each = var.gcp_creds != null ? [1] : []
    content {
      name  = "openobserve.secrets.ZO_S3_ACCESS_KEY"
      value = "/creds/creds.json"
    }
  }

  set {
    name  = "openobserve.env.ZO_S3_PROVIDER"
    value = "gcs"
  }

  set {
    name  = "openobserve.env.ZO_S3_SERVER_URL"
    value = "https://storage.googleapis.com"
  }

  depends_on = [
    kubernetes_secret_v1.docker_login,
    kubernetes_secret_v1.paragon_secrets
  ]
}

# monitors deployment
resource "helm_release" "paragon_monitoring" {
  count = var.monitors_enabled ? 1 : 0

  name              = "paragon-monitoring"
  description       = "Paragon monitors"
  chart             = "./charts/paragon-monitoring"
  version           = "${var.monitor_version}-${local.chart_hashes["paragon-monitoring"]}"
  namespace         = "paragon"
  cleanup_on_fail   = true
  create_namespace  = false
  atomic            = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true

  values = [
    local.global_values,
    local.monitor_values,
    local.public_monitor_values,
    local.secret_hash
  ]

  depends_on = [
    helm_release.paragon_on_prem,
    kubernetes_secret_v1.docker_login,
    kubernetes_secret_v1.paragon_secrets,
    kubectl_manifest.grafana_backendconfig
  ]
}
