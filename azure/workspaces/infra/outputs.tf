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
  value       = module.storage.blob.logs_container
  sensitive   = true
}

output "minio" {
  description = "MinIO server connection info."
  value = {
    public_bucket     = module.storage.blob.public_container
    private_bucket    = module.storage.blob.private_container
    microservice_user = module.storage.blob.minio_microservice_user
    microservice_pass = module.storage.blob.minio_microservice_pass
    root_user         = module.storage.blob.name
    root_password     = module.storage.blob.access_key
  }
  sensitive = true
}

output "redis" {
  description = "Connection information for Redis."
  value       = module.redis.redis
  sensitive   = true
}

output "cluster_name" {
  description = "The name of the AKS cluster."
  value       = module.cluster.kubernetes.name
}

output "resource_group" {
  description = "Resource Group that infrastructure was deployed to."
  value = {
    name     = module.network.resource_group.name
    location = module.network.resource_group.location
  }
}
