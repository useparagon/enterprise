# ServiceAccounts for Hoop access
resource "kubernetes_service_account" "hoop_cluster_admin" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-cluster-admin"
    namespace = var.namespace_paragon.id
    annotations = merge(
      {
        "kubernetes.io/service-account.name" = "hoop-cluster-admin"
      },
      try(google_service_account.hoop_agent[0].email, null) != null ? {
        "iam.gke.io/gcp-service-account" = google_service_account.hoop_agent[0].email
      } : {}
    )
  }
  depends_on = [helm_release.hoopagent]
}
