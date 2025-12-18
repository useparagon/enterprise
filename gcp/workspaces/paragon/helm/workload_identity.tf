# Workload Identity IAM bindings
# These bindings allow Kubernetes service accounts to impersonate the GCP service account
# when using Workload Identity
resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each = var.storage_service_account != null ? toset(local.cloud_storage_services) : []

  service_account_id = "projects/${data.google_container_cluster.cluster.project}/serviceAccounts/${var.storage_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.google_container_cluster.cluster.project}.svc.id.goog[${local.namespace}/${each.value}]"
}
