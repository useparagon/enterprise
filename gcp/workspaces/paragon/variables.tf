# credentials
variable "gcp_credential_json_file" {
  description = "The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided."
  type        = string
  default     = null
}

variable "gcp_project_id" {
  description = "The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`."
  type        = string
  default     = null
}

variable "gcp_private_key_id" {
  description = "The id of the private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_private_key" {
  description = "The private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_email" {
  description = "The client email for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_id" {
  description = "The client id for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_x509_cert_url" {
  description = "The client certificate url for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

# account
variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string

  validation {
    condition     = length(var.organization) <= 16
    error_message = "The `organization` input must be 16 or less characters."
  }
}

variable "environment" {
  description = "Type of environment being deployed to."
  type        = string
  default     = "enterprise"
}

variable "domain" {
  description = "The root domain used for the microservices."
  type        = string
}

variable "docker_registry_server" {
  description = "Docker container registry server."
  type        = string
  default     = "docker.io"
}

variable "docker_username" {
  description = "Docker username to pull images."
  type        = string
}

variable "docker_password" {
  description = "Docker password to pull images."
  type        = string
}

variable "docker_email" {
  description = "Docker email to pull images."
  type        = string
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone" {
  description = "The zone in the region where to host Google Cloud Organization resources."
  type        = string
}

variable "monitors_enabled" {
  description = "Specifies that monitors are enabled."
  type        = bool
  default     = false
}

variable "monitor_version" {
  description = "The version of the Paragon monitors to install."
  type        = string
  default     = null
}

variable "excluded_microservices" {
  description = "The microservices that should be excluded from the deployment."
  type        = list(string)
  default     = []
}

variable "ingress_scheme" {
  description = "Whether the load balancer is 'external' (public) or 'internal' (private)"
  type        = string
  default     = "external"
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.31"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Zone `DNS`"
  type        = string
  sensitive   = true
  default     = null
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id to set CNAMEs."
  type        = string
  default     = null
}

variable "uptime_api_token" {
  description = "Optional API Token for setting up BetterStack Uptime monitors."
  type        = string
  default     = null
}

variable "uptime_company" {
  description = "Optional pretty company name to include in BetterStack Uptime monitors."
  type        = string
  default     = null
}

variable "openobserve_email" {
  description = "OpenObserve admin login email."
  type        = string
  default     = null
}

variable "openobserve_password" {
  description = "OpenObserve admin login password."
  type        = string
  default     = null
}

variable "infra_json_path" {
  description = "Path to `infra` workspace output JSON file."
  type        = string
  default     = ".secure/infra-output.json"
}

variable "infra_json" {
  description = "JSON string of `infra` workspace variables to use instead of `infra_json_path`"
  type        = string
  default     = null
}

variable "helm_yaml_path" {
  description = "Path to helm values.yaml file."
  type        = string
  default     = ".secure/values.yaml"
}

variable "helm_yaml" {
  description = "YAML string of helm values to use instead of `helm_yaml_path`"
  type        = string
  default     = null
}

locals {
  creds_json     = try(jsondecode(file(var.gcp_credential_json_file)), {})
  gcp_project_id = try(local.creds_json.project_id, var.gcp_project_id)

  gcp_creds = jsonencode({
    type                        = "service_account",
    auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs",
    auth_uri                    = "https://accounts.google.com/o/oauth2/auth",
    token_uri                   = "https://oauth2.googleapis.com/token",
    client_email                = try(local.creds_json.client_email, var.gcp_client_email),
    client_id                   = try(local.creds_json.client_id, var.gcp_client_id),
    client_x509_cert_url        = try(local.creds_json.client_x509_cert_url, var.gcp_client_x509_cert_url),
    gcp_project_id              = try(local.creds_json.gcp_project_id, var.gcp_project_id),
    private_key                 = try(local.creds_json.private_key, var.gcp_private_key),
    private_key_id              = try(local.creds_json.private_key_id, var.gcp_private_key_id),
  })

  # hash of project ID to help ensure uniqueness of resources like bucket names
  hash      = substr(sha256(local.gcp_project_id), 0, 8)
  workspace = nonsensitive("paragon-${var.organization}-${local.hash}")

  default_labels = {
    name         = local.workspace
    environment  = var.environment
    organization = var.organization
    creator      = "terraform"
  }

  dns_enabled = var.ingress_scheme != "internal" && var.cloudflare_api_token != null && var.cloudflare_zone_id != null

  infra_json_path = abspath(var.infra_json_path)
  infra_vars      = jsondecode(fileexists(local.infra_json_path) && var.infra_json == null ? file(local.infra_json_path) : var.infra_json)

  # use default where standard value can be determined
  cluster_name = try(local.infra_vars.cluster_name.value, local.workspace)
  logs_bucket  = try(local.infra_vars.logs_bucket.value, "${local.workspace}-logs")

  helm_yaml_path = abspath(var.helm_yaml_path)
  helm_vars      = yamldecode(fileexists(local.helm_yaml_path) && var.helm_yaml == null ? file(local.helm_yaml_path) : var.helm_yaml)

  all_microservices = {
    "account" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["ACCOUNT_PORT"], 1708)
      "public_url"       = try(local.helm_vars.global.env["ACCOUNT_PUBLIC_URL"], "https://account.${var.domain}")
    }
    "cache-replay" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["CACHE_REPLAY_PORT"], 1724)
      "public_url"       = try(local.helm_vars.global.env["CACHE_REPLAY_PUBLIC_URL"], "https://cache-replay.${var.domain}")
    }
    "cerberus" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["CERBERUS_PORT"], 1700)
      "public_url"       = try(local.helm_vars.global.env["CERBERUS_PUBLIC_URL"], "https://cerberus.${var.domain}")
    }
    "connect" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["CONNECT_PORT"], 1707)
      "public_url"       = try(local.helm_vars.global.env["CONNECT_PUBLIC_URL"], "https://connect.${var.domain}")
    }
    "dashboard" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["DASHBOARD_PORT"], 1704)
      "public_url"       = try(local.helm_vars.global.env["DASHBOARD_PUBLIC_URL"], "https://dashboard.${var.domain}")
    }
    "flipt" = {
      "healthcheck_path" = "/health"
      "port"             = try(local.helm_vars.global.env["FLIPT_PORT"], 1722)
      "public_url"       = try(local.helm_vars.global.env["FLIPT_PUBLIC_URL"], null)
    }
    "hades" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["HADES_PORT"], 1710)
      "public_url"       = try(local.helm_vars.global.env["HADES_PUBLIC_URL"], "https://hades.${var.domain}")
    }
    "hermes" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["HERMES_PORT"], 1702)
      "public_url"       = try(local.helm_vars.global.env["HERMES_PUBLIC_URL"], "https://hermes.${var.domain}")
    }
    "minio" = {
      "healthcheck_path" = "/minio/health/live"
      "port"             = try(local.helm_vars.global.env["MINIO_PORT"], 9000)
      "public_url"       = try(local.helm_vars.global.env["MINIO_PUBLIC_URL"], "https://minio.${var.domain}")
    }
    "passport" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["PASSPORT_PORT"], 1706)
      "public_url"       = try(local.helm_vars.global.env["PASSPORT_PUBLIC_URL"], "https://passport.${var.domain}")
    }
    "pheme" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["PHEME_PORT"], 1709)
      "public_url"       = try(local.helm_vars.global.env["PHEME_PUBLIC_URL"], "https://pheme.${var.domain}")
    }
    "release" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["RELEASE_PORT"], 1719)
      "public_url"       = try(local.helm_vars.global.env["RELEASE_PUBLIC_URL"], "https://release.${var.domain}")
    }
    "zeus" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["ZEUS_PORT"], 1703)
      "public_url"       = try(local.helm_vars.global.env["ZEUS_PUBLIC_URL"], "https://zeus.${var.domain}")
    }
    "worker-actionkit" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_ACTIONKIT_PORT"], 1721)
      "public_url"       = try(local.helm_vars.global.env["WORKER_ACTIONKIT_PUBLIC_URL"], "https://worker-actionkit.${var.domain}")
    }
    "worker-actions" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_ACTIONS_PORT"], 1712)
      "public_url"       = try(local.helm_vars.global.env["WORKER_ACTIONS_PUBLIC_URL"], "https://worker-actions.${var.domain}")
    }
    "worker-credentials" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_CREDENTIALS_PORT"], 1713)
      "public_url"       = try(local.helm_vars.global.env["WORKER_CREDENTIALS_PUBLIC_URL"], "https://worker-credentials.${var.domain}")
    }
    "worker-crons" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_CRONS_PORT"], 1714)
      "public_url"       = try(local.helm_vars.global.env["WORKER_CRONS_PUBLIC_URL"], "https://worker-crons.${var.domain}")
    }
    "worker-deployments" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_DEPLOYMENTS_PORT"], 1718)
      "public_url"       = try(local.helm_vars.global.env["WORKER_DEPLOYMENTS_PUBLIC_URL"], "https://worker-deployments.${var.domain}")
    }
    "worker-proxy" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_PROXY_PORT"], 1715)
      "public_url"       = try(local.helm_vars.global.env["WORKER_PROXY_PUBLIC_URL"], "https://worker-proxy.${var.domain}")
    }
    "worker-triggers" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_TRIGGERS_PORT"], 1716)
      "public_url"       = try(local.helm_vars.global.env["WORKER_TRIGGERS_PUBLIC_URL"], "https://worker-triggers.${var.domain}")
    }
    "worker-workflows" = {
      "healthcheck_path" = "/healthz"
      "port"             = try(local.helm_vars.global.env["WORKER_WORKFLOWS_PORT"], 1717)
      "public_url"       = try(local.helm_vars.global.env["WORKER_WORKFLOWS_PUBLIC_URL"], "https://worker-workflows.${var.domain}")
    }
  }

  microservices = {
    for microservice, config in local.all_microservices :
    microservice => config
    if !contains(var.excluded_microservices, microservice)
  }

  public_microservices = {
    for microservice, config in local.microservices :
    microservice => config
    if config.public_url != null && config.public_url != ""
  }

  monitors = {
    "bull-exporter" = {
      "port"       = 9538
      "public_url" = null
    }
    "grafana" = {
      "port"       = 4500
      "public_url" = try(local.helm_vars.global.env["MONITOR_GRAFANA_SERVER_DOMAIN"], "https://grafana.${var.domain}")
    }
    "kube-state-metrics" = {
      "port"       = 2550
      "public_url" = null
    }
    "pgadmin" = {
      "port"       = 5050
      "public_url" = null
    }
    "prometheus" = {
      "port"       = 9090
      "public_url" = null
    }
    "postgres-exporter" = {
      "port"       = 9187
      "public_url" = null
    }
    "redis-exporter" = {
      "port"       = 9121
      "public_url" = null
    }
    "redis-insight" = {
      "port"       = 8500
      "public_url" = null
    }
  }

  public_monitors = var.monitors_enabled ? {
    for monitor, config in local.monitors :
    monitor => config
    if lookup(config, "public_url", null) != null
  } : {}

  public_services = merge(local.public_microservices, local.public_monitors)

  helm_keys_to_remove = [
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "POSTGRES_DATABASE",
    "REDIS_HOST",
    "REDIS_PORT",
  ]

  default_redis_cluster = try(
    local.helm_vars.global.env["REDIS_CLUSTER"],
    local.infra_vars.redis.value.cache.cluster,
    "false"
  )

  default_redis_ssl = try(
    local.helm_vars.global.env["REDIS_SSL"],
    local.infra_vars.redis.value.cache.ssl,
    "false"
  )

  default_redis_url = try(
    local.helm_vars.global.env["REDIS_URL"],
    "${local.helm_vars.global.env["REDIS_HOST"]}:${local.helm_vars.global.env["REDIS_PORT"]}",
    "${local.infra_vars.redis.value.cache.host}:${local.infra_vars.redis.value.cache.port}"
  )

  helm_values = merge(local.helm_vars, {
    global = merge(local.helm_vars.global, {
      env = merge(local.helm_vars.global.env, {
        for key, value in merge({
          // default values, can be overridden by `values.yaml -> global.env`
          NODE_ENV           = "production"
          PLATFORM_ENV       = "enterprise"
          BRANCH             = "main"
          SENDGRID_API_KEY   = "SG.xxx"
          EMAIL_FROM_ADDRESS = "not-a-real@email.com"

          ACCOUNT_PUBLIC_URL   = try(local.microservices.account.public_url, null)
          CERBERUS_PUBLIC_URL  = try(local.microservices.cerberus.public_url, null)
          CONNECT_PUBLIC_URL   = try(local.microservices.connect.public_url, null)
          DASHBOARD_PUBLIC_URL = try(local.microservices.dashboard.public_url, null)
          HADES_PUBLIC_URL     = try(local.microservices.hades.public_url, null)
          HERMES_PUBLIC_URL    = try(local.microservices.hermes.public_url, null)
          MINIO_PUBLIC_URL     = try(local.microservices.minio.public_url, null)
          PASSPORT_PUBLIC_URL  = try(local.microservices.passport.public_url, null)
          PHEME_PUBLIC_URL     = try(local.microservices.pheme.public_url, null)
          ZEUS_PUBLIC_URL      = try(local.microservices.zeus.public_url, null)

          WORKER_ACTIONKIT_PUBLIC_URL   = try(local.microservices["worker-actionkit"].public_url, null)
          WORKER_ACTIONS_PUBLIC_URL     = try(local.microservices["worker-actions"].public_url, null)
          WORKER_CREDENTIALS_PUBLIC_URL = try(local.microservices["worker-credentials"].public_url, null)
          WORKER_CRONS_PUBLIC_URL       = try(local.microservices["worker-crons"].public_url, null)
          WORKER_DEPLOYMENTS_PUBLIC_URL = try(local.microservices["worker-deployments"].public_url, null)
          WORKER_PROXY_PUBLIC_URL       = try(local.microservices["worker-proxy"].public_url, null)
          WORKER_TRIGGERS_PUBLIC_URL    = try(local.microservices["worker-triggers"].public_url, null)
          WORKER_WORKFLOWS_PUBLIC_URL   = try(local.microservices["worker-workflows"].public_url, null)

          MONITOR_GRAFANA_SLACK_CANARY_CHANNEL          = "<PLACEHOLDER>"
          MONITOR_GRAFANA_SLACK_CANARY_BETA_CHANNEL     = "<PLACEHOLDER>"
          MONITOR_GRAFANA_SLACK_CANARY_WEBHOOK_URL      = "<PLACEHOLDER>"
          MONITOR_GRAFANA_SLACK_CANARY_BETA_WEBHOOK_URL = "<PLACEHOLDER>"

          MICROSERVICES_OPENTELEMETRY_ENABLED = false
          },
          // custom values provided in `values.yaml`, overrides default values
          local.helm_vars.global.env,
          {
            // transformations, take priority over `values.yaml` -> global.env
            ORGANIZATION   = var.organization
            PARAGON_DOMAIN = var.domain
            HOST_ENV       = "GCP_K8"

            // worker variables
            HERCULES_CLUSTER_MAX_INSTANCES = 1
            HERCULES_CLUSTER_DISABLED      = true

            ADMIN_BASIC_AUTH_USERNAME = local.helm_vars.global.env["LICENSE"]
            ADMIN_BASIC_AUTH_PASSWORD = local.helm_vars.global.env["LICENSE"]

            CERBERUS_POSTGRES_HOST     = try(local.infra_vars.postgres.value.cerberus.host, local.infra_vars.postgres.value.postgres.host)
            CERBERUS_POSTGRES_PORT     = try(local.infra_vars.postgres.value.cerberus.port, local.infra_vars.postgres.value.postgres.port)
            CERBERUS_POSTGRES_USERNAME = try(local.infra_vars.postgres.value.cerberus.user, local.infra_vars.postgres.value.postgres.user)
            CERBERUS_POSTGRES_PASSWORD = try(local.infra_vars.postgres.value.cerberus.password, local.infra_vars.postgres.value.postgres.password)
            CERBERUS_POSTGRES_DATABASE = try(local.infra_vars.postgres.value.cerberus.database, local.infra_vars.postgres.value.postgres.database)
            HERMES_POSTGRES_HOST       = try(local.infra_vars.postgres.value.hermes.host, local.infra_vars.postgres.value.postgres.host)
            HERMES_POSTGRES_PORT       = try(local.infra_vars.postgres.value.hermes.port, local.infra_vars.postgres.value.postgres.port)
            HERMES_POSTGRES_USERNAME   = try(local.infra_vars.postgres.value.hermes.user, local.infra_vars.postgres.value.postgres.user)
            HERMES_POSTGRES_PASSWORD   = try(local.infra_vars.postgres.value.hermes.password, local.infra_vars.postgres.value.postgres.password)
            HERMES_POSTGRES_DATABASE   = try(local.infra_vars.postgres.value.hermes.database, local.infra_vars.postgres.value.postgres.database)
            PHEME_POSTGRES_HOST        = try(local.infra_vars.postgres.value.hermes.host, local.infra_vars.postgres.value.postgres.host)
            PHEME_POSTGRES_PORT        = try(local.infra_vars.postgres.value.hermes.port, local.infra_vars.postgres.value.postgres.port)
            PHEME_POSTGRES_USERNAME    = try(local.infra_vars.postgres.value.hermes.user, local.infra_vars.postgres.value.postgres.user)
            PHEME_POSTGRES_PASSWORD    = try(local.infra_vars.postgres.value.hermes.password, local.infra_vars.postgres.value.postgres.password)
            PHEME_POSTGRES_DATABASE    = try(local.infra_vars.postgres.value.hermes.database, local.infra_vars.postgres.value.postgres.database)
            ZEUS_POSTGRES_HOST         = try(local.infra_vars.postgres.value.zeus.host, local.infra_vars.postgres.value.postgres.host)
            ZEUS_POSTGRES_PORT         = try(local.infra_vars.postgres.value.zeus.port, local.infra_vars.postgres.value.postgres.port)
            ZEUS_POSTGRES_USERNAME     = try(local.infra_vars.postgres.value.zeus.user, local.infra_vars.postgres.value.postgres.user)
            ZEUS_POSTGRES_PASSWORD     = try(local.infra_vars.postgres.value.zeus.password, local.infra_vars.postgres.value.postgres.password)
            ZEUS_POSTGRES_DATABASE     = try(local.infra_vars.postgres.value.zeus.database, local.infra_vars.postgres.value.postgres.database)

            REDIS_URL = local.default_redis_url

            CACHE_REDIS_CLUSTER_ENABLED    = try(local.infra_vars.redis.value.cache.cluster, local.default_redis_cluster)
            CACHE_REDIS_TLS_ENABLED        = try(local.infra_vars.redis.value.cache.ssl, local.default_redis_ssl)
            CACHE_REDIS_URL                = try("${local.infra_vars.redis.value.cache.host}:${local.infra_vars.redis.value.cache.port}", local.default_redis_url)
            QUEUE_REDIS_CLUSTER_ENABLED    = try(local.infra_vars.redis.value.queue.cluster, local.default_redis_cluster)
            QUEUE_REDIS_TLS_ENABLED        = try(local.infra_vars.redis.value.queue.ssl, local.default_redis_ssl)
            QUEUE_REDIS_URL                = try("${local.infra_vars.redis.value.queue.host}:${local.infra_vars.redis.value.queue.port}", local.default_redis_url)
            SYSTEM_REDIS_CLUSTER_ENABLED   = try(local.infra_vars.redis.value.system.cluster, local.default_redis_cluster)
            SYSTEM_REDIS_TLS_ENABLED       = try(local.infra_vars.redis.value.system.ssl, local.default_redis_ssl)
            SYSTEM_REDIS_URL               = try("${local.infra_vars.redis.value.system.host}:${local.infra_vars.redis.value.system.port}", local.default_redis_url)
            WORKFLOW_REDIS_CLUSTER_ENABLED = try(local.infra_vars.redis.value.workflow.cluster, local.default_redis_cluster)
            WORKFLOW_REDIS_TLS_ENABLED     = try(local.infra_vars.redis.value.workflow.ssl, local.default_redis_ssl)
            WORKFLOW_REDIS_URL             = try("${local.infra_vars.redis.value.workflow.host}:${local.infra_vars.redis.value.workflow.port}", local.default_redis_url)

            MINIO_BROWSER           = "off"
            MINIO_INSTANCE_COUNT    = "1"
            MINIO_MICROSERVICE_PASS = local.infra_vars.minio.value.microservice_pass
            MINIO_MICROSERVICE_USER = local.infra_vars.minio.value.microservice_user
            MINIO_MODE              = "gateway-gcp"
            MINIO_NGINX_PROXY       = "on"
            MINIO_PUBLIC_BUCKET     = try(local.infra_vars.minio.value.public_bucket, "${local.workspace}-cdn")
            MINIO_ROOT_PASSWORD     = local.infra_vars.minio.value.root_password
            MINIO_ROOT_USER         = local.infra_vars.minio.value.root_user
            MINIO_SYSTEM_BUCKET     = try(local.infra_vars.minio.value.private_bucket, "${local.workspace}-app")

            CLOUD_STORAGE_MICROSERVICE_PASS = try(local.helm_vars.global.env["CLOUD_STORAGE_TYPE"], "GCP") == "GCP" ? local.infra_vars.minio.value.root_password : local.infra_vars.minio.value.microservice_pass
            CLOUD_STORAGE_MICROSERVICE_USER = try(local.helm_vars.global.env["CLOUD_STORAGE_TYPE"], "GCP") == "GCP" ? local.infra_vars.minio.value.root_user : local.infra_vars.minio.value.microservice_user
            CLOUD_STORAGE_PUBLIC_BUCKET     = try(local.infra_vars.minio.value.public_bucket, "${local.workspace}-cdn")
            CLOUD_STORAGE_SYSTEM_BUCKET     = try(local.infra_vars.minio.value.private_bucket, "${local.workspace}-app")
            CLOUD_STORAGE_TYPE              = try(local.helm_vars.global.env["CLOUD_STORAGE_TYPE"], "GCP")

            CLOUD_STORAGE_PUBLIC_URL = coalesce(
              try(local.helm_vars.global.env["CLOUD_STORAGE_PUBLIC_URL"], null),
              try(local.helm_vars.global.env["CLOUD_STORAGE_TYPE"], "GCP") == "GCP" ? "https://storage.googleapis.com" : null,
              try(local.microservices.minio.public_url, null), null
            )
            # TODO: In the future, we should use a private link to access the storage account so traffic stays within the VPC. This affects costs and performance.
            CLOUD_STORAGE_PRIVATE_URL = coalesce(
              try(local.helm_vars.global.env["CLOUD_STORAGE_PUBLIC_URL"], null),
              try(local.helm_vars.global.env["CLOUD_STORAGE_TYPE"], "GCP") == "GCP" ? "https://storage.googleapis.com" : null,
              try(local.microservices.minio.public_url, null), null
            )

            ACCOUNT_PORT   = try(local.microservices.account.port, null)
            CACHE_REPLAY_PORT   = try(local.microservices["cache-replay"].port, null)
            CERBERUS_PORT  = try(local.microservices.cerberus.port, null)
            CONNECT_PORT   = try(local.microservices.connect.port, null)
            DASHBOARD_PORT = try(local.microservices.dashboard.port, null)
            HADES_PORT     = try(local.microservices.hades.port, null)
            HERMES_PORT    = try(local.microservices.hermes.port, null)
            MINIO_PORT     = try(local.microservices.minio.port, null)
            PASSPORT_PORT  = try(local.microservices.passport.port, null)
            PHEME_PORT     = try(local.microservices.pheme.port, null)
            RELEASE_PORT   = try(local.microservices.release.port, null)
            ZEUS_PORT      = try(local.microservices.zeus.port, null)

            WORKER_ACTIONKIT_PORT   = try(local.microservices["worker-actionkit"].port, null)
            WORKER_ACTIONS_PORT     = try(local.microservices["worker-actions"].port, null)
            WORKER_CREDENTIALS_PORT = try(local.microservices["worker-credentials"].port, null)
            WORKER_CRONS_PORT       = try(local.microservices["worker-crons"].port, null)
            WORKER_DEPLOYMENTS_PORT = try(local.microservices["worker-deployments"].port, null)
            WORKER_PROXY_PORT       = try(local.microservices["worker-proxy"].port, null)
            WORKER_TRIGGERS_PORT    = try(local.microservices["worker-triggers"].port, null)
            WORKER_WORKFLOWS_PORT   = try(local.microservices["worker-workflows"].port, null)

            ACCOUNT_PRIVATE_URL   = try("http://account:${local.microservices.account.port}", null)
            CACHE_REPLAY_PRIVATE_URL   = try("http://cache-replay:${local.microservices["cache-replay"].port}", null)
            CERBERUS_PRIVATE_URL  = try("http://cerberus:${local.microservices.cerberus.port}", null)
            CONNECT_PRIVATE_URL   = try("http://connect:${local.microservices.connect.port}", null)
            DASHBOARD_PRIVATE_URL = try("http://dashboard:${local.microservices.dashboard.port}", null)
            EMBASSY_PRIVATE_URL   = "http://embassy:1705"
            HADES_PRIVATE_URL     = try("http://hades:${local.microservices.hades.port}", null)
            HERMES_PRIVATE_URL    = try("http://hermes:${local.microservices.hermes.port}", null)
            MINIO_PRIVATE_URL     = try("http://minio:${local.microservices.minio.port}", null)
            PASSPORT_PRIVATE_URL  = try("http://passport:${local.microservices.passport.port}", null)
            PHEME_PRIVATE_URL     = try("http://pheme:${local.microservices.pheme.port}", null)
            RELEASE_PRIVATE_URL   = try("http://release:${local.microservices.release.port}", null)
            ZEUS_PRIVATE_URL      = try("http://zeus:${local.microservices.zeus.port}", null)

            WORKER_ACTIONKIT_PRIVATE_URL   = try("http://worker-actionkit:${local.microservices["worker-actionkit"].port}", null)
            WORKER_ACTIONS_PRIVATE_URL     = try("http://worker-actions:${local.microservices["worker-actions"].port}", null)
            WORKER_CREDENTIALS_PRIVATE_URL = try("http://worker-credentials:${local.microservices["worker-credentials"].port}", null)
            WORKER_CRONS_PRIVATE_URL       = try("http://worker-crons:${local.microservices["worker-crons"].port}", null)
            WORKER_DEPLOYMENTS_PRIVATE_URL = try("http://worker-deployments:${local.microservices["worker-deployments"].port}", null)
            WORKER_PROXY_PRIVATE_URL       = try("http://worker-proxy:${local.microservices["worker-proxy"].port}", null)
            WORKER_TRIGGERS_PRIVATE_URL    = try("http://worker-triggers:${local.microservices["worker-triggers"].port}", null)
            WORKER_WORKFLOWS_PRIVATE_URL   = try("http://worker-workflows:${local.microservices["worker-workflows"].port}", null)

            FEATURE_FLAG_PLATFORM_ENDPOINT = "http://flipt:${local.microservices.flipt.port}"

            MONITOR_BULL_EXPORTER_HOST              = "http://bull-exporter"
            MONITOR_BULL_EXPORTER_PORT              = try(local.monitors["bull-exporter"].port, null)
            MONITOR_GRAFANA_HOST                    = "http://grafana"
            MONITOR_GRAFANA_PORT                    = try(local.monitors["grafana"].port, null)
            MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD = var.monitors_enabled ? module.monitors[0].grafana_admin_password : null
            MONITOR_GRAFANA_SECURITY_ADMIN_USER     = var.monitors_enabled ? module.monitors[0].grafana_admin_email : null
            MONITOR_GRAFANA_SERVER_DOMAIN           = try(local.monitors["grafana"].public_url, null)
            MONITOR_GRAFANA_UPTIME_WEBHOOK_URL      = module.uptime.webhook
            MONITOR_KUBE_STATE_METRICS_HOST         = "http://kube-state-metrics"
            MONITOR_KUBE_STATE_METRICS_PORT         = try(local.monitors["kube-state-metrics"].port, null)
            MONITOR_PGADMIN_EMAIL                   = var.monitors_enabled ? module.monitors[0].pgadmin_admin_email : null
            MONITOR_PGADMIN_HOST                    = "http://pgadmin"
            MONITOR_PGADMIN_PASSWORD                = var.monitors_enabled ? module.monitors[0].pgadmin_admin_password : null
            MONITOR_PGADMIN_PORT                    = try(local.monitors["pgadmin"].port, null)
            MONITOR_PGADMIN_SSL_MODE                = "require"
            MONITOR_POSTGRES_EXPORTER_HOST          = "http://postgres-exporter"
            MONITOR_POSTGRES_EXPORTER_PORT          = try(local.monitors["postgres-exporter"].port, null)
            MONITOR_POSTGRES_EXPORTER_SSL_MODE      = "require"
            MONITOR_PROMETHEUS_HOST                 = "http://prometheus"
            MONITOR_PROMETHEUS_PORT                 = try(local.monitors["prometheus"].port, null)
            MONITOR_QUEUE_REDIS_TARGET              = try(local.infra_vars.redis.value.queue.host, local.infra_vars.redis.value.cache.host)
            MONITOR_REDIS_EXPORTER_HOST             = "http://redis-exporter"
            MONITOR_REDIS_EXPORTER_PORT             = try(local.monitors["redis-exporter"].port, null)
            MONITOR_REDIS_INSIGHT_HOST              = "http://redis-insight"
            MONITOR_REDIS_INSIGHT_PORT              = try(local.monitors["redis-insight"].port, null)
        }) : key => value if !contains(local.helm_keys_to_remove, key) && value != null
      })
    })
  })

  monitor_version = var.monitor_version != null ? var.monitor_version : try(local.helm_values.global.env["VERSION"], "latest")

  flipt_options = {
    for key, value in merge(
      # user overrides
      local.helm_vars.global.env,
      {
        FLIPT_CACHE_ENABLED             = "true"
        FLIPT_STORAGE_GIT_POLL_INTERVAL = "30s"
        FLIPT_STORAGE_GIT_REF           = "main"
        FLIPT_STORAGE_GIT_REPOSITORY    = "https://github.com/useparagon/feature-flags.git"
        FLIPT_STORAGE_READ_ONLY         = "true"
        FLIPT_STORAGE_TYPE              = "git"
    }) :
    key => value
    if key != null && startswith(key, "FLIPT_") && value != null && value != ""
  }
}
