output "postgres" {
  value = {
    for key, value in local.postgres_instances :
    key => {
      host     = azurerm_postgresql_flexible_server.postgres[key].fqdn
      port     = var.postgres_port
      user     = random_string.postgres_root_username[key].result
      password = random_password.postgres_root_password[key].result
      database = azurerm_postgresql_flexible_server_database.paragon[key].name
    }
  }
  sensitive = true
}
