locals {
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
    }
  })

  global_values = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global = merge(
        nonsensitive(var.helm_values.global),
        {
          env = {
            HOST_ENV    = "AWS_K8"
            k8s_version = var.k8s_version
            secretName  = "paragon-secrets"
          },
          paragon_version = var.helm_values.global.env["VERSION"]
        }
      )
    }
  ))

  supported_microservices_values = <<EOF
subchart:
  account:
    enabled: ${contains(keys(var.microservices), "account")}
  cerberus:
    enabled: ${contains(keys(var.microservices), "cerberus")}
  connect:
    enabled: ${contains(keys(var.microservices), "connect")}
  dashboard:
    enabled: ${contains(keys(var.microservices), "dashboard")}
  flipt:
    enabled: ${contains(keys(var.microservices), "flipt")}
  hades:
    enabled: ${contains(keys(var.microservices), "hades")}
  hermes:
    enabled: ${contains(keys(var.microservices), "hermes")}
  minio:
    enabled: ${contains(keys(var.microservices), "minio")}
  passport:
    enabled: ${contains(keys(var.microservices), "passport")}
  pheme:
    enabled: ${contains(keys(var.microservices), "pheme")}
  release:
    enabled: ${contains(keys(var.microservices), "release")}
  zeus:
    enabled: ${contains(keys(var.microservices), "zeus")}
  worker-actionkit:
    enabled: ${contains(keys(var.microservices), "worker-actionkit")}
  worker-actions:
    enabled: ${contains(keys(var.microservices), "worker-actions")}
  worker-credentials:
    enabled: ${contains(keys(var.microservices), "worker-credentials")}
  worker-crons:
    enabled: ${contains(keys(var.microservices), "worker-crons")}
  worker-deployments:
    enabled: ${contains(keys(var.microservices), "worker-deployments")}
  worker-proxy:
    enabled: ${contains(keys(var.microservices), "worker-proxy")}
  worker-triggers:
    enabled: ${contains(keys(var.microservices), "worker-triggers")}
  worker-workflows:
    enabled: ${contains(keys(var.microservices), "worker-workflows")}
EOF
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

# ingress controller; provisions load balancer
resource "helm_release" "ingress" {
  name        = "ingress"
  description = "AWS Ingress Controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.9.1"

  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  namespace        = kubernetes_namespace.paragon.id
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

  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
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
    local.supported_microservices_values,
    local.flipt_values,
    local.global_values
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
      name  = "${set.key}.ingress.host"
      value = replace(replace(set.value.public_url, "https://", ""), "http://", "")
    }
  }

  # configures whether the load balancer is 'internet-facing' (public) or 'internal' (private)
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.ingress.scheme"
      value = var.ingress_scheme
    }
  }

  # configures the ssl cert to the load balancer
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.ingress.acm_certificate_arn"
      value = var.acm_certificate_arn
    }
  }

  # configures the load balancer name
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.ingress.load_balancer_name"
      value = var.workspace
    }
  }

  # configures load balancer bucket for logging
  dynamic "set" {
    for_each = var.public_microservices

    content {
      name  = "${set.key}.ingress.logs_bucket"
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
    kubernetes_storage_class_v1.gp3_encrypted
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
    local.global_values
  ]

  # used to load environment variables into microservices
  dynamic "set_sensitive" {
    for_each = nonsensitive(merge(var.helm_values.global.env))
    content {
      name  = "global.env.${set_sensitive.key}"
      value = set_sensitive.value
    }
  }

  # set image tag to pull
  dynamic "set" {
    for_each = var.monitors

    content {
      name  = "${set.key}.image.tag"
      value = var.monitor_version
    }
  }

  # used to set map the ingress to the public url of each microservice
  dynamic "set" {
    for_each = var.public_monitors

    content {
      name  = "${set.key}.ingress.host"
      value = replace(replace(set.value.public_url, "https://", ""), "http://", "")
    }
  }

  # configures whether the load balancer is 'internet-facing' (public) or 'internal' (private)
  dynamic "set" {
    for_each = var.public_monitors

    content {
      name  = "${set.key}.ingress.scheme"
      value = var.ingress_scheme
    }
  }

  # configures the ssl cert to the load balancer
  dynamic "set" {
    for_each = var.public_monitors

    content {
      name  = "${set.key}.ingress.acm_certificate_arn"
      value = var.acm_certificate_arn
    }
  }

  # configures the load balancer name
  dynamic "set" {
    for_each = var.public_monitors

    content {
      name  = "${set.key}.ingress.load_balancer_name"
      value = var.workspace
    }
  }

  # configures load balancer bucket for logging
  dynamic "set" {
    for_each = var.monitors

    content {
      name  = "${set.key}.ingress.logs_bucket"
      value = var.logs_bucket
    }
  }

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
