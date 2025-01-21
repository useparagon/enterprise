resource "google_redis_instance" "redis" {
  for_each = local.redis_instances

  name           = "${var.workspace}-redis-${each.key}"
  display_name   = "${var.workspace}-redis-${each.key}"
  memory_size_gb = each.value.size
  redis_version  = "REDIS_6_X"
  tier           = "STANDARD_HA"

  project                 = var.gcp_project_id
  authorized_network      = var.network.id
  region                  = var.region
  location_id             = var.region_zone
  alternative_location_id = var.region_zone_backup
}
