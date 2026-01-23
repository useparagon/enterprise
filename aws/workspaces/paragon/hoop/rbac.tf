# RBAC for the ServiceAccounts
resource "kubernetes_cluster_role_binding" "hoop_cluster_admin" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name = "hoop-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.hoop_cluster_admin[0].metadata[0].name
    namespace = var.namespace_paragon.id
  }
  depends_on = [kubernetes_service_account.hoop_cluster_admin]
}
