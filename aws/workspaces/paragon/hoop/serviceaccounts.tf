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
      try(aws_iam_role.hoop_support[0].arn, null) != null ? {
        "eks.amazonaws.com/role-arn" = aws_iam_role.hoop_support[0].arn
      } : {}
    )
  }
  depends_on = [helm_release.hoopagent]
}
