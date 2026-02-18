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
    } : {},
    # For managed_sync only: postgres superuser so postgres-config-openfga init can run GRANT on schema public.
    local.openfga_instance_key != null ? {
      postgres_superuser = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = "postgres"
        password = random_password.postgres_superuser_password[0].result
        database = "postgres"
      }
    } : {}
  )
  sensitive = true
}
