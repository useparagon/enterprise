resource "google_compute_global_address" "paragon" {
  name          = "${var.workspace}-global-psconnect-ip"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = var.network.id
  prefix_length = 16
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.paragon.name]
}

# Instance name must use only lowercase letters, numbers, hyphens (no underscores).
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

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "paragon" {
  for_each = local.postgres_instances

  name     = each.key
  project  = var.gcp_project_id
  instance = google_sql_database_instance.paragon[each.key].name
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
