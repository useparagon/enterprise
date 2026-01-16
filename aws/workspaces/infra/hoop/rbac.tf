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
    namespace = var.hoop_namespace
  }
  depends_on = [kubernetes_service_account.hoop_cluster_admin]
}

# Readonly access to all namespaces
resource "kubernetes_cluster_role_binding" "hoop_paragon_admin_readonly" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name = "hoop-paragon-admin-readonly"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.hoop_paragon_admin[0].metadata[0].name
    namespace = var.hoop_namespace
  }
  depends_on = [kubernetes_service_account.hoop_paragon_admin]
}

# RoleBinding for admin access in paragon namespace
resource "kubernetes_role_binding" "hoop_paragon_admin" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-paragon-admin"
    namespace = "paragon"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.hoop_paragon_admin[0].metadata[0].name
    namespace = var.hoop_namespace
  }
  depends_on = [kubernetes_service_account.hoop_paragon_admin]
}
