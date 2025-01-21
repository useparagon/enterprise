output "postgres" {
  value = {
    for name, config in local.postgres_instances :
    name => {
      host     = google_sql_database_instance.paragon[name].ip_address.0.ip_address
      port     = "5432"
      user     = random_string.postgres_root_username[name].result
      password = random_password.postgres_root_password[name].result
      database = google_sql_database.paragon[name].name
    }
  }
  sensitive = true
}
