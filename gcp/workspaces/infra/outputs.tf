output "workspace" {
  description = "The resource group that all resources are associated with."
  value       = local.workspace
}

output "bastion" {
  description = "Bastion server connection info."
  value = {
    public_dns  = module.bastion.connection.bastion_dns
    private_key = module.bastion.connection.private_key
  }
  sensitive = true
}

output "postgres" {
  description = "Connection info for Postgres."
  value       = module.postgres.postgres
  sensitive   = true
}

output "logs_container" {
  description = "The bucket used to store system logs."
  value       = module.storage.storage.logs_bucket
  sensitive   = true
}

output "minio" {
  description = "MinIO server connection info."
  value = {
    public_bucket     = module.storage.storage.public_bucket
    private_bucket    = module.storage.storage.private_bucket
    microservice_user = module.storage.storage.minio_microservice_user
    microservice_pass = module.storage.storage.minio_microservice_pass
  }
  sensitive = true
}

output "redis" {
  description = "Connection information for Redis."
  value       = module.redis.redis
  sensitive   = true
}

output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = module.cluster.kubernetes.name
}
