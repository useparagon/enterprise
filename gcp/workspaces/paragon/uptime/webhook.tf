resource "betteruptime_grafana_integration" "webhook" {
  count = local.enabled ? 1 : 0

  name = "Enterprise ${var.uptime_company}"

  call  = true
  email = true
  push  = true
  sms   = true

  recovery_period = 0
  team_wait       = 300
}
