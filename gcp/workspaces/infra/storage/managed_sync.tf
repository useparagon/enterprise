# Managed Sync bucket (homologue to AWS S3 workspace-managed-sync).
# Used by Managed Sync for storage; same MinIO SA has access for paragon.
resource "google_storage_bucket" "managed_sync" {
  count         = var.managed_sync_enabled ? 1 : 0
  name          = "${var.workspace}-managed-sync"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "managed_sync" {
  count  = var.managed_sync_enabled ? 1 : 0
  bucket = google_storage_bucket.managed_sync[0].name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.minio.email}"
}
