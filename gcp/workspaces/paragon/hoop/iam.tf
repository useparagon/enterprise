# GCP Service Account for Hoop agent with Editor access via Workload Identity
resource "google_service_account" "hoop_agent" {
  count = var.hoop_enabled && var.gcp_project_id != null ? 1 : 0

  account_id   = "hoop-support-${substr(md5(var.workspace), 0, 8)}"
  display_name = "Hoop Support"
  description  = "Service account for Hoop agent support access."
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "hoop_support" {
  count = var.hoop_enabled && var.gcp_project_id != null ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.hoop_agent[0].email}"
}

resource "google_service_account_iam_member" "hoop_workload_identity" {
  count = var.hoop_enabled && var.gcp_project_id != null ? 1 : 0

  service_account_id = google_service_account.hoop_agent[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.namespace_paragon.id}/hoop-cluster-admin]"
}
