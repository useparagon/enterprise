output "workspace" {
  description = "The resource group that all resources are associated with."
  value       = local.workspace
}

output "postgres" {
  description = "Connection info for Postgres."
  value       = module.postgres.rds
  sensitive   = true
}

output "redis" {
  description = "Connection information for Redis."
  value       = module.redis.elasticache
  sensitive   = true
}

output "logs_bucket" {
  description = "The bucket used to store system logs."
  value       = module.s3.s3.logs_bucket
  sensitive   = true
}

output "minio" {
  description = "MinIO server connection info."
  value = {
    public_bucket     = module.s3.s3.public_bucket
    private_bucket    = module.s3.s3.private_bucket
    microservice_user = module.s3.s3.minio_microservice_user
    microservice_pass = module.s3.s3.minio_microservice_pass
    root_user         = module.s3.s3.access_key_id
    root_password     = module.s3.s3.access_key_secret
  }
  sensitive = true
}

output "bastion" {
  description = "Bastion server connection info."
  value = {
    public_dns  = module.bastion.connection.bastion_dns
    private_key = module.bastion.connection.private_key
  }
  sensitive = true
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.cluster.eks_cluster.name
}
