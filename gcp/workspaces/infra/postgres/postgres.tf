# Instance name must use only lowercase letters, numbers, hyphens (no underscores).
# Depends on service_networking_connection (in network module) so destroy order is: instances first, then connection.
resource "google_sql_database_instance" "paragon" {
  for_each = local.postgres_instances

  name                = "${var.workspace}-${replace(each.key, "_", "-")}"
  project             = var.gcp_project_id
  region              = var.region
  database_version    = "POSTGRES_14"
  deletion_protection = !var.disable_deletion_protection

  settings {
    disk_autoresize = true
    tier            = each.value.tier

    backup_configuration {
      binary_log_enabled = false
    }

    database_flags {
      name  = "max_connections"
      value = 5000
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  depends_on = [var.service_networking_connection]
}

# Depend on users so destroy order is: databases first, then users (Cloud SQL cannot drop a role that owns objects).
resource "google_sql_database" "paragon" {
  for_each = local.postgres_instances

  name       = each.key
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[each.key].name
  depends_on = [google_sql_user.postgres_user]
}

resource "random_string" "postgres_root_username" {
  for_each = local.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = local.postgres_instances

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "postgres_user" {
  for_each = local.postgres_instances

  name     = random_string.postgres_root_username[each.key].result
  password = random_password.postgres_root_password[each.key].result
  instance = google_sql_database_instance.paragon[each.key].name
  project  = var.gcp_project_id
}

# OpenFGA for managed-sync: DB and user in Terraform so the chart init only runs GRANTs (avoids "Error granting schema privileges").
locals {
  openfga_instance_key = var.managed_sync_enabled ? (contains(keys(local.postgres_instances), "managed_sync") ? "managed_sync" : "paragon") : null
  # DBs created by the app on managed_sync; we manage them in TF so destroy drops them before users (postgres cannot be dropped while owning these).
  managed_sync_extra_db_names = toset(local.openfga_instance_key != null ? ["sync_project", "sync_instance"] : [])
}

# Depend on openfga and postgres_superuser so destroy order is: DB first, then users (Cloud SQL cannot drop a role that owns/has privileges on objects).
resource "google_sql_database" "openfga" {
  count = local.openfga_instance_key != null ? 1 : 0

  name       = "openfga"
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[local.openfga_instance_key].name
  depends_on = [google_sql_user.openfga, google_sql_user.postgres_superuser]
}

# managed_sync app-created DBs: declare in TF so destroy drops them before users (postgres owns them; cannot drop role otherwise).
# If they already exist, import before apply: terraform import 'google_sql_database.managed_sync_extra["sync_project"]' PROJECT_ID:INSTANCE_NAME:sync_project (same for sync_instance).
resource "google_sql_database" "managed_sync_extra" {
  for_each = local.managed_sync_extra_db_names

  name       = each.value
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[local.openfga_instance_key].name
  depends_on = [google_sql_user.openfga, google_sql_user.postgres_superuser]
}

resource "random_string" "openfga_username" {
  count = local.openfga_instance_key != null ? 1 : 0

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "openfga_password" {
  count = local.openfga_instance_key != null ? 1 : 0

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "openfga" {
  count = local.openfga_instance_key != null ? 1 : 0

  name     = random_string.openfga_username[0].result
  password = random_password.openfga_password[0].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}

# Cloud SQL default user "postgres" (superuser). Exported via output for managed_sync only so the
# postgres-config-openfga init can connect as postgres and run GRANT on schema public successfully.
resource "random_password" "postgres_superuser_password" {
  count = local.openfga_instance_key != null ? 1 : 0

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "postgres_superuser" {
  count = local.openfga_instance_key != null ? 1 : 0

  name     = "postgres"
  password = random_password.postgres_superuser_password[0].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}
