locals {
  namespace = "paragon"
  version   = var.helm_values.global.env["VERSION"]

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
          paragon_version = local.version
        }
      )
    }
  ))

  # Same as AWS: helm_values with only global.env.HOST_ENV for managed_sync (repo chart).
  global_values_minus_env = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global = merge(nonsensitive(var.helm_values).global, { env = { HOST_ENV = "GCP_K8" } })
    }
  ))

  # Managed Sync: same pattern as paragon_on_prem — base = full var.helm_values (.secure/values.yaml),
  # only override global.env.HOST_ENV and secret_hash so minio/etcd/kafka/postgresql/redis enabled: false apply.
  managed_sync_values = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global      = merge(nonsensitive(var.helm_values).global, { env = { HOST_ENV = "GCP_K8" } })
      secret_hash = { secret_hash = sha256(jsonencode(nonsensitive(var.helm_values))) }
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

# shared secrets (paragon-secrets always; paragon-managed-sync-secrets when managed_sync enabled)
resource "kubernetes_secret_v1" "paragon_secrets" {
  for_each = toset(var.managed_sync_enabled ? ["paragon-secrets", "paragon-managed-sync-secrets"] : ["paragon-secrets"])

  metadata {
    name      = each.value
    namespace = kubernetes_namespace_v1.paragon.id
  }

  type = "Opaque"

  data = {
    # Map global.env from helm_values into secret data (includes managed_sync_secrets when enabled)
    for key, value in nonsensitive(var.helm_values.global.env) :
    key => value
  }
}

# Redis CA certificate secret (for TLS connections)
# Use infra_vars passed from parent module (already parsed from infra-output.json)
locals {
  # Extract all Redis CA certificates
  redis_ca_certificates = {
    cache  = try(var.infra_vars.redis.value.cache.ca_certificate, null)
    queue  = try(var.infra_vars.redis.value.queue.ca_certificate, null)
    system = try(var.infra_vars.redis.value.system.ca_certificate, null)
  }
  # Check if any certificates are available
  has_redis_ca_certs = local.redis_ca_certificates.cache != null || local.redis_ca_certificates.queue != null || local.redis_ca_certificates.system != null
  # Combine all certificates into a single bundle (Node.js can use this)
  # Each certificate already contains newlines (\n escape sequences from JSON)
  # Filter out null/empty values before joining with double newline separator
  redis_ca_cert_bundle = length(compact([
    for cert in [local.redis_ca_certificates.cache, local.redis_ca_certificates.queue, local.redis_ca_certificates.system] :
    cert if cert != null && cert != ""
    ])) > 0 ? "${join("\n\n", compact([
      for cert in [local.redis_ca_certificates.cache, local.redis_ca_certificates.queue, local.redis_ca_certificates.system] :
      cert if cert != null && cert != ""
  ]))}\n" : ""
}

# Redis CA certificate secret (for TLS connections)
# Contains all Redis instance CA certificates
resource "kubernetes_secret_v1" "redis_ca_cert" {
  # Only create if at least one certificate is available
  count = local.has_redis_ca_certs ? 1 : 0

  metadata {
    name      = "redis-ca-cert"
    namespace = kubernetes_namespace_v1.paragon.id
  }

  type = "Opaque"

  data = {
    # Combined bundle for NODE_EXTRA_CA_CERTS (all certificates in one file)
    # Note: Kubernetes secrets automatically base64 encode the data field, so we don't encode here
    "server-ca.pem" = local.redis_ca_cert_bundle
  }
}

# microservices deployment
resource "helm_release" "paragon_on_prem" {
  name              = "paragon-on-prem"
  description       = "Paragon microservices"
  chart             = "./charts/paragon-onprem"
  version           = "${local.version}-${local.chart_hashes["paragon-onprem"]}"
  namespace         = kubernetes_namespace_v1.paragon.id
  create_namespace  = false
  cleanup_on_fail   = true
  atomic            = true
  verify            = false
  timeout           = 900 # 15 minutes
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
    kubernetes_config_map_v1.feature_flag_content,
    kubernetes_secret_v1.redis_ca_cert
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name              = "paragon-logging"
  description       = "Paragon logging services"
  chart             = "./charts/paragon-logging"
  version           = "${local.version}-${local.chart_hashes["paragon-logging"]}"
  namespace         = kubernetes_namespace_v1.paragon.id
  create_namespace  = false
  cleanup_on_fail   = true
  atomic            = true
  verify            = false
  timeout           = 900 # 15 minutes
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
