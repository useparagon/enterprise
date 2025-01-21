output "storage" {
  value = {
    private_bucket          = google_storage_bucket.app.name
    public_bucket           = google_storage_bucket.cdn.name
    logs_bucket             = google_storage_bucket.logs.name
    minio_microservice_user = random_string.minio_microservice_user.result
    minio_microservice_pass = random_password.minio_microservice_pass.result
    private_key             = google_service_account_key.minio.private_key
  }
  sensitive = true
}
