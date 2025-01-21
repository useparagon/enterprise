output "redis" {
  value = var.multi_redis ? {
    for key, value in local.redis_instances :
    key => {
      host = google_redis_instance.redis[key].host
      port = google_redis_instance.redis[key].port
    }
    } : {
    cache = {
      host = google_redis_instance.redis["cache"].host
      port = google_redis_instance.redis["cache"].port
    }
  }
  sensitive = true
}
