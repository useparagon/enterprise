resource "google_service_account" "minio" {
  account_id   = "minio-root-user"
  display_name = "Minio"
  description  = "Allows Minio to read and write to Google Cloud Storage."
  project      = var.gcp_project_id
}

resource "google_service_account_key" "minio" {
  count = var.use_storage_account_key ? 1 : 0

  service_account_id = google_service_account.minio.name
}

# Custom role for listing buckets only (minimal permissions)
resource "google_project_iam_custom_role" "bucket_lister" {
  role_id     = "storageBucketLister"
  title       = "Storage Bucket Lister"
  description = "Minimal role that only allows listing buckets in the project"
  permissions = ["storage.buckets.list"]
  project     = var.gcp_project_id
}

# Grant project-level permission to allow listing buckets for health-checker
resource "google_project_iam_member" "minio_bucket_lister" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.bucket_lister.name
  member  = "serviceAccount:${google_service_account.minio.email}"
}
