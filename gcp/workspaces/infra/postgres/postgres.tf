resource "google_compute_global_address" "paragon" {
  name          = "${var.workspace}-global-psconnect-ip"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = var.network.id
  project       = var.gcp_project_id
  prefix_length = 16
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.paragon.name]
}

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

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

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

locals {
  openfga_instance_key       = var.managed_sync_enabled ? (contains(keys(local.postgres_instances), "managed_sync") ? "managed_sync" : "paragon") : null
  managed_sync_extra_db_names = toset(local.openfga_instance_key != null ? ["sync_project", "sync_instance"] : [])
}

resource "google_sql_database" "openfga" {
  count = local.openfga_instance_key != null ? 1 : 0

  name       = "openfga"
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[local.openfga_instance_key].name
  depends_on = [google_sql_user.openfga]
}

# managed_sync: DBs and users in TF (destroy order: drop DBs before users).
resource "google_sql_database" "managed_sync_extra" {
  for_each = local.managed_sync_extra_db_names

  name       = each.value
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[local.openfga_instance_key].name
  depends_on = [google_sql_user.openfga, google_sql_user.sync_project, google_sql_user.sync_instance]
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

resource "random_string" "managed_sync_db_username" {
  for_each = local.managed_sync_extra_db_names

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "managed_sync_db_password" {
  for_each = local.managed_sync_extra_db_names

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "sync_project" {
  count = local.openfga_instance_key != null ? 1 : 0

  name     = random_string.managed_sync_db_username["sync_project"].result
  password = random_password.managed_sync_db_password["sync_project"].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}

resource "google_sql_user" "sync_instance" {
  count = local.openfga_instance_key != null ? 1 : 0

  name     = random_string.managed_sync_db_username["sync_instance"].result
  password = random_password.managed_sync_db_password["sync_instance"].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}

resource "random_password" "postgres_admin_password" {
  count = local.openfga_instance_key != null ? 1 : 0

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "postgres_admin" {
  count = local.openfga_instance_key != null ? 1 : 0

  name     = "postgres"
  password = random_password.postgres_admin_password[0].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}
