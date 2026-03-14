# Ensure the GCP SA used by api-sync, worker-sync, worker-history-sync (Workload Identity)
# has storage.admin on the managed_sync bucket. Infra already grants this to the MinIO SA;
# this binding guarantees the SA that paragon actually uses (from infra output) has access.
data "google_storage_bucket" "managed_sync" {
  count  = var.managed_sync_enabled && try(var.infra_vars.minio.value.managed_sync_bucket, null) != null && var.storage_service_account != null ? 1 : 0
  name   = var.infra_vars.minio.value.managed_sync_bucket
}

resource "google_storage_bucket_iam_member" "managed_sync" {
  count  = var.managed_sync_enabled && try(var.infra_vars.minio.value.managed_sync_bucket, null) != null && var.storage_service_account != null ? 1 : 0
  bucket = data.google_storage_bucket.managed_sync[0].name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.storage_service_account}"
}
