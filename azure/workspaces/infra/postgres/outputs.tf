output "postgres" {
  value = {
    postgres = {
      host     = azurerm_postgresql_flexible_server.postgres.fqdn
      port     = var.postgres_port
      user     = random_string.postgres_root_username.result
      password = random_password.postgres_root_password.result
      database = "paragon" # TODO azurerm_postgresql_database.paragon.name
    }
  }
  sensitive = true
}
