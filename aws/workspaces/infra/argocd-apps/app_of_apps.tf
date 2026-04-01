locals {
  all_applications = merge(
    {
      cluster-autoscaler = local.app_cluster_autoscaler
      ingress            = local.app_ingress
      metrics-server     = local.app_metrics_server
      nth                = local.app_nth
      paragon-onprem     = local.app_paragon_onprem
      paragon-logging    = local.app_paragon_logging
    },
    local.app_paragon_monitoring != null ? { paragon-monitoring = local.app_paragon_monitoring } : {},
    local.app_managed_sync != null ? { managed-sync = local.app_managed_sync } : {},
  )

  all_external_secrets = merge(
    {
      paragon-secrets = local.external_secret_paragon
      docker-cfg      = local.external_secret_docker
    },
    local.external_secret_managed_sync != null ? { managed-sync-secrets = local.external_secret_managed_sync } : {},
    local.external_secret_openobserve != null ? { openobserve-credentials = local.external_secret_openobserve } : {},
  )
}
