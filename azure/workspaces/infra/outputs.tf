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
    access_key        = module.storage.blob.access_key
  }
  sensitive = true
}

# output "redis" {
#   description = "Connection information for Redis."
#   value       = module.redis.elasticache
#   sensitive   = true
# }

# output "cluster_name" {
#   description = "The name of the EKS cluster."
#   value       = module.cluster.eks_cluster.name
# }
