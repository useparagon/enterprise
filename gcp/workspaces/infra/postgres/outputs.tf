output "postgres" {
  value = merge(
    {
      for name, config in local.postgres_instances :
      name => {
        host     = google_sql_database_instance.paragon[name].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.postgres_root_username[name].result
        password = random_password.postgres_root_password[name].result
        database = google_sql_database.paragon[name].name
      }
    },
    local.openfga_instance_key != null ? {
      openfga = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.openfga_username[0].result
        password = random_password.openfga_password[0].result
        database = "openfga"
      }
      sync_project = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.managed_sync_db_username["sync_project"].result
        password = random_password.managed_sync_db_password["sync_project"].result
        database = "sync_project"
      }
      sync_instance = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.managed_sync_db_username["sync_instance"].result
        password = random_password.managed_sync_db_password["sync_instance"].result
        database = "sync_instance"
      }
    } : {},
    # For managed_sync only: default "postgres" admin (part of cloudsqlsuperuser role), allowed from network.
    local.openfga_instance_key != null ? {
      postgres_superuser = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = "postgres"
        password = random_password.postgres_admin_password[0].result
        database = "postgres"
      }
    } : {}
  )
  sensitive = true
}
