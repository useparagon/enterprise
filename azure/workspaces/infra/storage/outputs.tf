output "storage" {
  value = {
    name                    = local.storage_account_name
    access_key              = azurerm_storage_account.blob.primary_access_key
    private_container       = local.private_container_name
    public_container        = local.public_container_name
    minio_microservice_user = random_string.minio_microservice_user.result
    minio_microservice_pass = random_string.minio_microservice_pass.result
  }
  sensitive = true
}
