locals {
  version = var.helm_values.global.env["VERSION"]

  helm_values_yaml = yamlencode(nonsensitive(var.helm_values))

  subchart_values = yamlencode({
    subchart = merge(
      merge(
        {
          for microservice in keys(var.microservices) : microservice => {
            enabled = true
          }
        },
        {
          kafka-exporter = {
            enabled = var.managed_sync_enabled
          }
        }
      ),
      try(nonsensitive(var.helm_values.subchart), {})
    )
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
      }
      persistence = var.feature_flags_content != null ? {
        enabled = true
      } : {}
      extraVolumes = var.feature_flags_content != null ? [
        {
          name = "feature-flags-content"
          configMap = {
            name = kubernetes_config_map.feature_flag_content[0].metadata[0].name
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
        className          = "alb"
        host               = replace(replace(microservice_config.public_url, "https://", ""), "http://", "")
        scheme             = var.ingress_scheme
        certificate        = var.certificate
        load_balancer_name = var.workspace
        logs_bucket        = var.logs_bucket
      }
    }
  })

  monitor_values = yamlencode({
    for monitor_name, monitor_config in var.monitors : monitor_name => {
      image = {
        tag = var.monitor_version
      }
      ingress = {
        logs_bucket = var.logs_bucket
      }
    }
  })

  public_monitor_values = yamlencode({
    for monitor_name, monitor_config in var.public_monitors : monitor_name => {
      ingress = {
        className          = "alb"
        host               = replace(replace(monitor_config.public_url, "https://", ""), "http://", "")
        scheme             = var.ingress_scheme
        certificate        = var.certificate
        load_balancer_name = var.workspace
      }
    }
  })

  global_values = yamlencode({
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
  })

  global_values_minus_env = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global = merge(nonsensitive(var.helm_values).global, { env = {
        HOST_ENV = "AWS_K8"
      } })
    }
  ))

  # changes to secrets should trigger redeploy
  secret_hash = yamlencode({
    secret_hash = sha256(jsonencode(nonsensitive(var.helm_values)))
  })
}

# creates the `paragon` namespace
resource "kubernetes_namespace" "paragon" {
  metadata {
    name = "paragon"

    annotations = {
      name = "paragon"
    }

    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "kubernetes_config_map" "feature_flag_content" {
  count = var.feature_flags_content != null ? 1 : 0

  metadata {
    name      = "feature-flags-content"
    namespace = kubernetes_namespace.paragon.id
  }

  data = {
    "features.yml" = var.feature_flags_content
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
  for_each = toset(
    var.managed_sync_enabled ? [
      "paragon-secrets",
      "paragon-managed-sync-secrets"
      ] : [
      "paragon-secrets"
    ]
  )
  metadata {
    name      = each.value
    namespace = kubernetes_namespace.paragon.id
  }

  type = "Opaque"

  data = {
    # Map global.env from helm_values into secret data
    for key, value in nonsensitive(var.helm_values.global.env) :
    key => value
  }
}

# ingress controller; provisions load balancer
resource "helm_release" "ingress" {
  name        = "ingress"
  description = "AWS Ingress Controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.9.1"

  namespace        = kubernetes_namespace.paragon.id
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  force_update     = true
  verify           = false

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "replicaCount"
    value = "3"
  }
}

# metrics server for hpa
resource "helm_release" "metricsserver" {
  name        = "metricsserver"
  description = "AWS Metrics Server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  namespace        = kubernetes_namespace.paragon.id
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  force_update     = true
  verify           = false

  depends_on = [
    helm_release.ingress
  ]
}

# graceful handling of spot evictions
module "aws_node_termination_handler" {
  source  = "qvest-digital/aws-node-termination-handler/kubernetes"
  version = "4.0.0"

  json_logging = true
}

# microservices deployment
resource "helm_release" "paragon_on_prem" {
  name        = "paragon-on-prem"
  description = "Paragon microservices"
  chart       = "./charts/paragon-onprem"
  version     = "${local.version}-${local.chart_hashes["paragon-onprem"]}"

  namespace         = kubernetes_namespace.paragon.id
  atomic            = true
  cleanup_on_fail   = true
  create_namespace  = false
  dependency_update = true
  force_update      = true
  timeout           = 900 # 15 minutes
  verify            = false

  values = [
    local.helm_values_yaml,
    local.subchart_values,
    local.global_values,
    local.flipt_values,
    local.microservice_values,
    local.public_microservice_values,
    local.secret_hash
  ]

  depends_on = [
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_secret.paragon_secrets,
    kubernetes_storage_class_v1.gp3_encrypted,
    kubernetes_config_map.feature_flag_content
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name        = "paragon-logging"
  description = "Paragon logging services"
  chart       = "./charts/paragon-logging"
  version     = "${local.version}-${local.chart_hashes["paragon-logging"]}"

  namespace         = kubernetes_namespace.paragon.id
  atomic            = true
  cleanup_on_fail   = true
  create_namespace  = false
  dependency_update = true
  force_update      = true
  timeout           = 900 # 15 minutes
  verify            = false

  values = [
    local.helm_values_yaml,
    local.global_values
  ]

  set {
    name  = "global.env.ZO_S3_PROVIDER"
    value = "s3"
  }

  set {
    name  = "global.env.ZO_S3_BUCKET_NAME"
    value = var.logs_bucket
  }

  set {
    name  = "global.env.ZO_S3_REGION_NAME"
    value = var.aws_region
  }

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

  depends_on = [
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_storage_class_v1.gp3_encrypted
  ]
}

# monitors deployment
resource "helm_release" "paragon_monitoring" {
  count = var.monitors_enabled ? 1 : 0

  name        = "paragon-monitoring"
  description = "Paragon monitors"
  chart       = "./charts/paragon-monitoring"
  version     = "${var.monitor_version}-${local.chart_hashes["paragon-monitoring"]}"

  namespace         = kubernetes_namespace.paragon.id
  atomic            = true
  cleanup_on_fail   = true
  create_namespace  = false
  dependency_update = true
  force_update      = true
  timeout           = 900 # 15 minutes
  verify            = false

  values = [
    local.helm_values_yaml,
    local.subchart_values,
    local.global_values,
    local.monitor_values,
    local.public_monitor_values,
    local.secret_hash
  ]

  set {
    name  = "global.env.k8s_version"
    value = var.k8s_version
  }

  set {
    name  = "global.env.MONITOR_GRAFANA_ALB_ARN"
    value = data.aws_lb.load_balancer.arn_suffix
  }

  depends_on = [
    helm_release.ingress,
    helm_release.paragon_on_prem,
    kubernetes_secret.docker_login,
    kubernetes_storage_class_v1.gp3_encrypted
  ]
}
