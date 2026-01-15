# ServiceAccounts for Hoop access
resource "kubernetes_service_account" "hoop_cluster_admin" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-cluster-admin"
    namespace = var.hoop_namespace
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-cluster-admin"
    }
  }
  depends_on = [helm_release.hoopagent]
}

resource "kubernetes_service_account" "hoop_paragon_admin" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-paragon-admin"
    namespace = var.hoop_namespace
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-paragon-admin"
    }
  }
  depends_on = [helm_release.hoopagent]
}
