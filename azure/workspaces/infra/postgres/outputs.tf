output "postgres" {
  value = {
    host     = azurerm_postgresql_server.postgresserver.fqdn
    port     = "5432"
    user     = random_string.postgres_root_username.result
    password = random_string.postgres_root_password.result
    database = azurerm_postgresql_database.paragon.name
  }
  sensitive = true
}
