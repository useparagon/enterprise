resource "google_service_account" "bastion" {
  account_id   = "bastion"
  display_name = "bastion"
  description  = "Bastion service account to access Kubernetes cluster."
}

data "google_iam_policy" "bastion" {
  binding {
    role = "roles/iam.serviceAccountUser"
    members = [
      google_service_account.bastion.member
    ]
  }
}

resource "google_service_account_iam_policy" "bastion" {
  service_account_id = google_service_account.bastion.name
  policy_data        = data.google_iam_policy.bastion.policy_data
}

resource "google_project_iam_member" "bastion_container_admin" {
  project = var.gcp_project_id
  role    = "roles/container.admin"
  member  = google_service_account.bastion.member
}
