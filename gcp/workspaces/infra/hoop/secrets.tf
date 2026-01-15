# Secrets for ServiceAccount tokens (Kubernetes will auto-populate the token)
resource "kubernetes_secret" "hoop_cluster_admin_token" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-cluster-admin-token"
    namespace = var.hoop_namespace
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-cluster-admin"
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account.hoop_cluster_admin
  ]
}

resource "kubernetes_secret" "hoop_paragon_admin_token" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-paragon-admin-token"
    namespace = var.hoop_namespace
    annotations = {
      "kubernetes.io/service-account.name" = "hoop-paragon-admin"
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account.hoop_paragon_admin
  ]
}

# Wait for Kubernetes to populate the tokens
resource "time_sleep" "wait_for_hoop_tokens" {
  count = var.hoop_enabled ? 1 : 0

  create_duration = "30s"

  depends_on = [
    kubernetes_secret.hoop_cluster_admin_token,
    kubernetes_secret.hoop_paragon_admin_token
  ]
}

# Read the tokens from the secrets
data "kubernetes_secret" "hoop_cluster_admin_token" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-cluster-admin-token"
    namespace = var.hoop_namespace
  }

  depends_on = [
    time_sleep.wait_for_hoop_tokens
  ]
}

data "kubernetes_secret" "hoop_paragon_admin_token" {
  count = var.hoop_enabled ? 1 : 0

  metadata {
    name      = "hoop-paragon-admin-token"
    namespace = var.hoop_namespace
  }

  depends_on = [
    time_sleep.wait_for_hoop_tokens
  ]
}
