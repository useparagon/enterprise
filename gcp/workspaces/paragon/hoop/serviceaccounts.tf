# ServiceAccounts for Hoop access
resource "kubernetes_service_account" "hoop_cluster_admin" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-cluster-admin"
    namespace = var.namespace_paragon.id
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-cluster-admin"
    }
  }
  depends_on = [helm_release.hoopagent]
}
