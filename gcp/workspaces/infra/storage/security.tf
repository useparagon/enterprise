resource "google_service_account" "minio" {
  account_id   = "minio-root-user"
  display_name = "Minio"
  description  = "Allows Minio to read and write to Google Cloud Storage."
  project      = var.gcp_project_id
}

resource "google_service_account_key" "minio" {
  service_account_id = google_service_account.minio.name
}
