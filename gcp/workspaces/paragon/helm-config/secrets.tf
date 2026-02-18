locals {
  _default_postgres_config = {
    host     = try(var.base_helm_values.global.env["ADMIN_POSTGRES_HOST"], try(var.infra_values.postgres.value.managed_sync.host, var.infra_values.postgres.value.paragon.host))
    port     = try(var.base_helm_values.global.env["ADMIN_POSTGRES_PORT"], try(var.infra_values.postgres.value.managed_sync.port, var.infra_values.postgres.value.paragon.port))
    user     = try(var.base_helm_values.global.env["ADMIN_POSTGRES_USERNAME"], try(var.infra_values.postgres.value.managed_sync.user, var.infra_values.postgres.value.paragon.user))
    password = try(var.base_helm_values.global.env["ADMIN_POSTGRES_PASSWORD"], try(var.infra_values.postgres.value.managed_sync.password, var.infra_values.postgres.value.paragon.password))
    database = try(var.base_helm_values.global.env["ADMIN_POSTGRES_DATABASE"], try(var.infra_values.postgres.value.managed_sync.database, var.infra_values.postgres.value.paragon.database))
  }

  postgres_config = {
    admin = {
      host     = local._default_postgres_config.host
      port     = local._default_postgres_config.port
      username = local._default_postgres_config.user
      password = local._default_postgres_config.password
      database = local._default_postgres_config.database
    }
    # Prefer infra openfga (GCP: DB and user created in Terraform to avoid init "Error granting schema privileges")
    openfga = {
      host     = try(var.base_helm_values.global.env["OPENFGA_POSTGRES_HOST"], try(var.infra_values.postgres.value.openfga.host, local._default_postgres_config.host))
      port     = try(var.base_helm_values.global.env["OPENFGA_POSTGRES_PORT"], try(var.infra_values.postgres.value.openfga.port, local._default_postgres_config.port))
      username = try(var.base_helm_values.global.env["OPENFGA_POSTGRES_USERNAME"], try(var.infra_values.postgres.value.openfga.user, random_string.postgres_username["openfga"].result))
      password = try(var.base_helm_values.global.env["OPENFGA_POSTGRES_PASSWORD"], try(var.infra_values.postgres.value.openfga.password, random_password.postgres_password["openfga"].result))
      database = "openfga"
    }
    sync_instance = {
      host     = try(var.base_helm_values.global.env["SYNC_INSTANCE_POSTGRES_HOST"], local._default_postgres_config.host)
      port     = try(var.base_helm_values.global.env["SYNC_INSTANCE_POSTGRES_PORT"], local._default_postgres_config.port)
      username = try(var.base_helm_values.global.env["SYNC_INSTANCE_POSTGRES_USERNAME"], random_string.postgres_username["sync_instance"].result)
      password = try(var.base_helm_values.global.env["SYNC_INSTANCE_POSTGRES_PASSWORD"], random_password.postgres_password["sync_instance"].result)
      database = "sync_instance"
    }
    sync_project = {
      host     = try(var.base_helm_values.global.env["SYNC_PROJECT_POSTGRES_HOST"], local._default_postgres_config.host)
      port     = try(var.base_helm_values.global.env["SYNC_PROJECT_POSTGRES_PORT"], local._default_postgres_config.port)
      username = try(var.base_helm_values.global.env["SYNC_PROJECT_POSTGRES_USERNAME"], random_string.postgres_username["sync_project"].result)
      password = try(var.base_helm_values.global.env["SYNC_PROJECT_POSTGRES_PASSWORD"], random_password.postgres_password["sync_project"].result)
      database = "sync_project"
    }
  }

  kafka_config = {
    broker_urls    = try(var.base_helm_values.global.env["MANAGED_SYNC_KAFKA_BROKER_URLS"], try(var.infra_values.kafka.value.cluster_bootstrap_brokers, ""))
    sasl_username  = try(var.base_helm_values.global.env["MANAGED_SYNC_KAFKA_SASL_USERNAME"], try(var.infra_values.kafka.value.cluster_username, ""))
    sasl_password  = try(var.base_helm_values.global.env["MANAGED_SYNC_KAFKA_SASL_PASSWORD"], try(var.infra_values.kafka.value.cluster_password, ""))
    sasl_mechanism = try(var.base_helm_values.global.env["MANAGED_SYNC_KAFKA_SASL_MECHANISM"], try(var.infra_values.kafka.value.cluster_mechanism, "plain"))
    ssl_enabled    = try(var.base_helm_values.global.env["MANAGED_SYNC_KAFKA_SSL_ENABLED"], try(var.infra_values.kafka.value.cluster_tls_enabled, true))
  }

  redis_config = {
    host                = try(var.base_helm_values.global.env["REDIS_HOST"], try(var.infra_values.redis.value.managed_sync.host, var.infra_values.redis.value.cache.host))
    port                = try(var.base_helm_values.global.env["REDIS_PORT"], try(var.infra_values.redis.value.managed_sync.port, var.infra_values.redis.value.cache.port))
    password            = try(var.base_helm_values.global.env["MANAGED_SYNC_REDIS_PASSWORD"], try(var.infra_values.redis.value.managed_sync.password, var.infra_values.redis.value.cache.password, null))
    cluster_enabled     = try(var.base_helm_values.global.env["MANAGED_SYNC_REDIS_CLUSTER_ENABLED"], try(var.infra_values.redis.value.managed_sync.cluster, var.infra_values.redis.value.cache.cluster, false))
    redis_tls_enabled   = try(var.base_helm_values.global.env["MANAGED_SYNC_REDIS_TLS_ENABLED"], try(var.infra_values.redis.value.managed_sync.ssl, var.infra_values.redis.value.cache.ssl, false))
    redis_ca_certificate = try(var.base_helm_values.global.env["MANAGED_SYNC_REDIS_CA_CERT"], try(var.infra_values.redis.value.managed_sync.ca_certificate, null))
  }

  # -------------------------------------------------------------------------
  # Managed Sync storage: same env var names as AWS (CLOUD_STORAGE_*) for chart compatibility.
  # AWS -> GCP mapping:
  #   CLOUD_STORAGE_TYPE                AWS: S3 | GCP: GCP
  #   CLOUD_STORAGE_PUBLIC_BUCKET       AWS: S3 bucket name (cdn) | GCP: GCS bucket name (cdn)
  #   CLOUD_STORAGE_MANAGED_SYNC_BUCKET AWS: S3 bucket name | GCP: GCS bucket name (managed_sync)
  #   CLOUD_STORAGE_PUBLIC_URL          AWS: https://s3.<region>.amazonaws.com | GCP: https://storage.googleapis.com
  #   CLOUD_STORAGE_PRIVATE_URL         same as PUBLIC_URL in both
  #   CLOUD_STORAGE_REGION              AWS: aws_region | GCP: region (e.g. us-central1)
  #   CLOUD_STORAGE_USER                AWS: S3 access key / MinIO user | GCP: project_id or SA email (infra minio.root_user)
  #   CLOUD_STORAGE_PASS                AWS: S3 secret key / MinIO pass | GCP: SA key JSON (infra minio.root_password when use_storage_account_key)
  # -------------------------------------------------------------------------
  storage_type = try(var.base_helm_values.global.env["CLOUD_STORAGE_TYPE"], "GCP")

  storage_config = {
    buckets = {
      public       = coalesce(try(var.base_helm_values.global.env["CLOUD_STORAGE_PUBLIC_BUCKET"], null), try(var.base_helm_values.global.env["MINIO_PUBLIC_BUCKET"], null), try(var.infra_values.minio.value.public_bucket, null))
      managed_sync = coalesce(try(var.base_helm_values.global.env["CLOUD_STORAGE_MANAGED_SYNC_BUCKET"], null), try(var.infra_values.minio.value.managed_sync_bucket, null))
    }
    type = try(var.base_helm_values.global.env["CLOUD_STORAGE_TYPE"], "GCP")
    # GCP: user = project_id or SA email; pass = service account key JSON (when use_storage_account_key)
    user = try(
      local.storage_type == "MINIO" ? try(var.base_helm_values.global.env["MINIO_MICROSERVICE_USER"], var.infra_values.minio.value.microservice_user) : try(var.base_helm_values.global.env["CLOUD_STORAGE_MICROSERVICE_USER"], var.infra_values.minio.value.root_user)
    )
    pass = try(
      local.storage_type == "MINIO" ? try(var.base_helm_values.global.env["MINIO_MICROSERVICE_PASS"], var.infra_values.minio.value.microservice_pass) : try(var.base_helm_values.global.env["CLOUD_STORAGE_MICROSERVICE_PASS"], var.infra_values.minio.value.root_password)
    )
    public_url = coalesce(
      try(var.base_helm_values.global.env["CLOUD_STORAGE_PUBLIC_URL"], null),
      local.storage_type == "GCP" ? "https://storage.googleapis.com" : null,
      try(var.microservices["minio"].public_url, null),
      null
    )
    # GCP region for GCS (e.g. us-central1); chart expects CLOUD_STORAGE_REGION
    region = try(var.base_helm_values.global.env["CLOUD_STORAGE_REGION"], var.region, "us-central1")
  }

  queue_exporter_config = {
    host     = try(var.microservices["queue-exporter"].host, null)
    port     = try(var.microservices["queue-exporter"].port, null)
    username = try(var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_HTTP_USERNAME"], random_string.queue_exporter_username.result)
    password = try(var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_HTTP_PASSWORD"], random_password.queue_exporter_password.result)
  }

  managed_sync_secrets = {
    HOST_ENV  = "GCP_K8"
    LOG_LEVEL = try(var.base_helm_values.global.env["LOG_LEVEL"], "debug")

    CLOUD_STORAGE_TYPE                = local.storage_type
    CLOUD_STORAGE_PUBLIC_BUCKET       = local.storage_config.buckets.public
    CLOUD_STORAGE_PRIVATE_URL         = local.storage_config.public_url
    CLOUD_STORAGE_PUBLIC_URL          = local.storage_config.public_url
    CLOUD_STORAGE_REGION              = local.storage_config.region
    CLOUD_STORAGE_USER                = local.storage_config.user
    # GCP: use same SA key as paragon (gcp_storage_sa_key) when provided; else storage_config.pass (infra minio.root_password)
    CLOUD_STORAGE_PASS                = local.storage_type == "GCP" && try(var.gcp_storage_sa_key, null) != null ? var.gcp_storage_sa_key : local.storage_config.pass
    CLOUD_STORAGE_MANAGED_SYNC_BUCKET = local.storage_config.buckets.managed_sync

    MANAGED_SYNC_URL       = try(var.base_helm_values.global.env["MANAGED_SYNC_URL"], "https://sync.${var.domain}")
    PARAGON_PROXY_BASE_URL = try("http://worker-proxy:${var.microservices["worker-proxy"].port}", null)
    PARAGON_ZEUS_BASE_URL  = try("http://zeus:${var.microservices["zeus"].port}", null)

    MANAGED_SYNC_PRIVATE_KEY      = replace(tls_private_key.managed_sync_signing_key.private_key_pem, "\n", "\\n")
    MANAGED_SYNC_AUTH_PUBLIC_KEY  = replace(tls_private_key.managed_sync_signing_key.public_key_pem, "\n", "\\n")

    MANAGED_SYNC_ETCD_HOSTS = join(",", [for i in range(3) : "http://etcd-${i}.etcd-headless:2379"])

    MANAGED_SYNC_KAFKA_BROKER_URLS    = local.kafka_config.broker_urls
    MANAGED_SYNC_KAFKA_SASL_USERNAME  = local.kafka_config.sasl_username
    # GMK SASL PLAIN expects the password (service account JSON key) to be base64-encoded.
    MANAGED_SYNC_KAFKA_SASL_PASSWORD  = local.kafka_config.sasl_mechanism == "plain" ? base64encode(local.kafka_config.sasl_password) : local.kafka_config.sasl_password
    MANAGED_SYNC_KAFKA_SASL_MECHANISM = local.kafka_config.sasl_mechanism
    MANAGED_SYNC_KAFKA_SSL_ENABLED    = tostring(local.kafka_config.ssl_enabled)

    # Use rediss:// when TLS so client uses TLS (Memorystore; plain redis:// causes "0x15" protocol error). Include password when set.
    MANAGED_SYNC_REDIS_URL              = try(var.base_helm_values.global.env["MANAGED_SYNC_REDIS_URL"], local.redis_config.redis_tls_enabled ? (local.redis_config.password != null ? "rediss://:${urlencode(local.redis_config.password)}@${local.redis_config.host}:${local.redis_config.port}" : "rediss://${local.redis_config.host}:${local.redis_config.port}") : (local.redis_config.password != null ? "redis://:${urlencode(local.redis_config.password)}@${local.redis_config.host}:${local.redis_config.port}" : "redis://${local.redis_config.host}:${local.redis_config.port}"))
    MANAGED_SYNC_REDIS_CLUSTER_ENABLED  = local.redis_config.cluster_enabled
    MANAGED_SYNC_REDIS_TLS_ENABLED      = tostring(local.redis_config.redis_tls_enabled)
    MANAGED_SYNC_REDIS_CA_CERT          = local.redis_config.redis_ca_certificate != null ? local.redis_config.redis_ca_certificate : ""

    SYNC_INSTANCE_POSTGRES_HOST        = local.postgres_config.sync_instance.host
    SYNC_INSTANCE_POSTGRES_PORT        = local.postgres_config.sync_instance.port
    SYNC_INSTANCE_POSTGRES_USERNAME    = local.postgres_config.sync_instance.username
    SYNC_INSTANCE_POSTGRES_PASSWORD    = local.postgres_config.sync_instance.password
    SYNC_INSTANCE_POSTGRES_DATABASE    = local.postgres_config.sync_instance.database
    SYNC_INSTANCE_POSTGRES_SSL_ENABLED = "true"

    SYNC_PROJECT_POSTGRES_HOST        = local.postgres_config.sync_project.host
    SYNC_PROJECT_POSTGRES_PORT        = local.postgres_config.sync_project.port
    SYNC_PROJECT_POSTGRES_USERNAME    = local.postgres_config.sync_project.username
    SYNC_PROJECT_POSTGRES_PASSWORD    = local.postgres_config.sync_project.password
    SYNC_PROJECT_POSTGRES_DATABASE    = local.postgres_config.sync_project.database
    SYNC_PROJECT_POSTGRES_SSL_ENABLED = "true"

    OPENFGA_HTTP_URL             = "http://openfga:6200"
    OPENFGA_POSTGRES_HOST        = local.postgres_config.openfga.host
    OPENFGA_POSTGRES_PORT        = local.postgres_config.openfga.port
    OPENFGA_POSTGRES_USERNAME    = local.postgres_config.openfga.username
    OPENFGA_POSTGRES_PASSWORD    = local.postgres_config.openfga.password
    OPENFGA_POSTGRES_DATABASE    = local.postgres_config.openfga.database
    OPENFGA_POSTGRES_SSL_ENABLED = "true"
    OPENFGA_POSTGRES_URI         = "postgres://${local.postgres_config.openfga.username}:${local.postgres_config.openfga.password}@${local.postgres_config.openfga.host}:${local.postgres_config.openfga.port}/${local.postgres_config.openfga.database}?sslmode=prefer"
    OPENFGA_AUTH_PRESHARED_KEY   = random_string.openfga_preshared_key.result

    # GCP: use postgres superuser for ADMIN_* so postgres-config-openfga init can GRANT on schema public.
    ADMIN_POSTGRES_HOST        = local.postgres_config.admin.host
    ADMIN_POSTGRES_PORT        = local.postgres_config.admin.port
    ADMIN_POSTGRES_USERNAME    = try(var.infra_values.postgres.value.postgres_superuser.user, local.postgres_config.admin.username)
    ADMIN_POSTGRES_PASSWORD    = try(var.infra_values.postgres.value.postgres_superuser.password, local.postgres_config.admin.password)
    # Use "postgres" so init can connect (openfga DB may not exist yet). Job main container uses -d openfga for GRANTs.
    ADMIN_POSTGRES_DATABASE    = try(var.infra_values.postgres.value.postgres_superuser.user, null) != null ? "postgres" : local.postgres_config.admin.database
    ADMIN_POSTGRES_SSL_ENABLED = "true"

    MANAGED_SYNC_POSTGRES_HOST        = local.postgres_config.admin.host
    MANAGED_SYNC_POSTGRES_PORT        = local.postgres_config.admin.port
    MANAGED_SYNC_POSTGRES_DATABASE    = local.postgres_config.admin.database
    MANAGED_SYNC_POSTGRES_USERNAME    = local.postgres_config.admin.username
    MANAGED_SYNC_POSTGRES_PASSWORD    = local.postgres_config.admin.password
    MANAGED_SYNC_POSTGRES_SSL_ENABLED = "true"

    OPENFGA_HTTP_PORT           = "6200"
    OPENFGA_GRPC_PORT           = "6201"
    OPENFGA_AUTH_METHOD        = "preshared"
    OPENFGA_AUTH_PRESHARED_KEYS = sha256(local.postgres_config.openfga.password)
    OPENFGA_HTTP_URL            = "http://openfga:6200"

    MANAGED_SYNC_ENABLED         = "true"
    MONITOR_MANAGED_SYNC_ENABLED = "true"

    MONITOR_MANAGED_SYNC_KAFKA_BROKER_URLS    = local.kafka_config.broker_urls
    MONITOR_MANAGED_SYNC_KAFKA_SASL_USERNAME  = local.kafka_config.sasl_username
    MONITOR_MANAGED_SYNC_KAFKA_SASL_PASSWORD  = local.kafka_config.sasl_mechanism == "plain" ? base64encode(local.kafka_config.sasl_password) : local.kafka_config.sasl_password
    MONITOR_MANAGED_SYNC_KAFKA_SASL_MECHANISM = local.kafka_config.sasl_mechanism
    MONITOR_MANAGED_SYNC_KAFKA_SSL_ENABLED    = tostring(local.kafka_config.ssl_enabled)

    MONITOR_QUEUE_EXPORTER_PRIVATE_URL = try(
      var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_PRIVATE_URL"],
      "http://queue-exporter:${try(var.microservices["queue-exporter"].port, 1806)}"
    )
    MONITOR_QUEUE_EXPORTER_PORT = try(
      var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_PORT"],
      var.base_helm_values.global.env["MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_PORT"],
      try(var.microservices["queue-exporter"].port, 1806),
      "1806"
    )
    MONITOR_QUEUE_EXPORTER_USERNAME = try(
      var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_USERNAME"],
      var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_HTTP_USERNAME"],
      var.base_helm_values.global.env["MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_HTTP_USERNAME"],
      random_string.queue_exporter_username.result
    )
    MONITOR_QUEUE_EXPORTER_PASSWORD = try(
      var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_PASSWORD"],
      var.base_helm_values.global.env["MONITOR_QUEUE_EXPORTER_HTTP_PASSWORD"],
      var.base_helm_values.global.env["MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_HTTP_PASSWORD"],
      random_password.queue_exporter_password.result
    )

    MONITOR_QUEUE_EXPORTER_HTTP_USERNAME              = local.queue_exporter_config.username
    MONITOR_QUEUE_EXPORTER_HTTP_PASSWORD              = local.queue_exporter_config.password
    MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_HOST          = local.queue_exporter_config.host
    MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_PORT          = local.queue_exporter_config.port
    MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_HTTP_USERNAME = local.queue_exporter_config.username
    MONITOR_MANAGED_SYNC_QUEUE_EXPORTER_HTTP_PASSWORD = local.queue_exporter_config.password

    MONITOR_MANAGED_SYNC_POSTGRES_HOST        = local.postgres_config.admin.host
    MONITOR_MANAGED_SYNC_POSTGRES_PORT        = local.postgres_config.admin.port
    MONITOR_MANAGED_SYNC_POSTGRES_USERNAME    = local.postgres_config.admin.username
    MONITOR_MANAGED_SYNC_POSTGRES_PASSWORD    = local.postgres_config.admin.password
    MONITOR_MANAGED_SYNC_POSTGRES_DATABASE    = local.postgres_config.admin.database
    MONITOR_MANAGED_SYNC_POSTGRES_SSL_ENABLED = "true"
  }
}

resource "random_string" "postgres_username" {
  for_each = toset(local.postgres_instances)

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_password" {
  for_each = toset(local.postgres_instances)

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "random_string" "queue_exporter_username" {
  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "queue_exporter_password" {
  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "random_string" "openfga_preshared_key" {
  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "tls_private_key" "managed_sync_signing_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
