# Hoop agent deployment
resource "helm_release" "hoopagent" {
  count = var.hoop_enabled ? 1 : 0

  name       = "hoopagent"
  repository = "oci://ghcr.io/hoophq/helm-charts"
  chart      = "hoopagent-chart"
  version    = var.hoop_version
  namespace  = var.namespace_paragon.id

  cleanup_on_fail  = true
  create_namespace = false
  atomic           = true
  verify           = false
  timeout          = 300

  set {
    name  = "config.HOOP_KEY"
    value = "grpcs://${coalesce(var.hoop_agent_name, var.organization)}:${var.hoop_key}@${var.hoop_server}?mode=standard"
  }

  set {
    name  = "image.tag"
    value = var.hoop_version
  }
}
