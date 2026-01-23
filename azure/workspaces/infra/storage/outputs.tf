output "blob" {
  value = {
    name                    = local.storage_account_name
    access_key              = azurerm_storage_account.blob.primary_access_key
    private_container       = azurerm_storage_container.app.name
    public_container        = azurerm_storage_container.cdn.name
    logs_container          = azurerm_storage_container.logs.name
    auditlogs_container     = azurerm_storage_container.auditlogs.name
    minio_microservice_user = random_string.minio_microservice_user.result
    minio_microservice_pass = random_password.minio_microservice_pass.result
  }
  sensitive = true
}
