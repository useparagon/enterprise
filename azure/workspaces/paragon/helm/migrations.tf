moved {
  from = kubernetes_secret.paragon_secrets
  to   = kubernetes_secret.paragon_secrets["paragon-secrets"]
}
