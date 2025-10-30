# private bucket
resource "google_storage_bucket" "app" {
  name          = "${var.workspace}-app"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection
}

resource "google_storage_bucket_iam_member" "app" {
  bucket = google_storage_bucket.app.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.minio.email}"
}

# public bucket
resource "google_storage_bucket" "cdn" {
  name          = "${var.workspace}-cdn"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection
}

resource "google_storage_bucket_iam_member" "cdn" {
  bucket = google_storage_bucket.cdn.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.minio.email}"
}

resource "google_storage_bucket_acl" "cdn_public_read_access" {
  bucket = google_storage_bucket.cdn.name
  role_entity = [
    "READER:allUsers"
  ]
}

# configure all objects added to the public bucket to have public read access
resource "google_storage_default_object_acl" "cdn_public_read_access" {
  bucket = google_storage_bucket.cdn.name
  role_entity = [
    "READER:allUsers"
  ]
}

# logs bucket
resource "google_storage_bucket" "logs" {
  name          = "${var.workspace}-logs"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection
}

resource "google_storage_bucket_iam_member" "logs" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.minio.email}"
}
