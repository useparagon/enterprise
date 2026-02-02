output "storage" {
  value = {
    private_bucket          = google_storage_bucket.app.name
    public_bucket           = google_storage_bucket.cdn.name
    logs_bucket             = google_storage_bucket.logs.name
    auditlogs_bucket        = google_storage_bucket.auditlogs.name
    minio_microservice_user = var.use_storage_account_key ? random_string.minio_microservice_user.result : null
    minio_microservice_pass = var.use_storage_account_key ? random_password.minio_microservice_pass.result : null
    service_account         = google_service_account.minio.email
    private_key             = var.use_storage_account_key ? google_service_account_key.minio[0].private_key : null
    project_id              = var.gcp_project_id
    region                  = var.region
  }
  sensitive = true
}
