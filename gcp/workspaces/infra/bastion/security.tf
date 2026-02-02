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

# GCE load balancer permissions for the bastion service account.
# We use a predefined role (instead of a custom role) because creating/updating custom
# roles requires IAM permissions like `iam.roles.get` that we may not have in this workspace.
#
# This role is sufficient for:
# - compute ssl-certificates describe/list
# - compute target-https-proxies describe/update (attach new cert)
resource "google_project_iam_member" "bastion_gclb_ops" {
  project = var.gcp_project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = google_service_account.bastion.member
}
