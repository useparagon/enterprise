output "workspace" {
  description = "The resource group that all resources are associated with."
  value       = local.workspace
}

output "environment" {
  description = "The development environment (e.g. sandbox, development, staging, production, enterprise)."
  value       = local.environment
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

output "minio_root_user" {
  description = "The root username for Minio service."
  value       = module.s3.s3.access_key_id
  sensitive   = true
}

output "minio_root_password" {
  description = "The root password for Minio service."
  value       = module.s3.s3.access_key_secret
  sensitive   = true
}

output "minio_microservice_user" {
  description = "The username for the microservices to connect to Minio."
  value       = module.s3.s3.minio_microservice_user
  sensitive   = true
}

output "minio_microservice_pass" {
  description = "The pass for the microservices to connect to Minio."
  value       = module.s3.s3.minio_microservice_pass
  sensitive   = true
}

output "minio_public_bucket" {
  description = "The public bucket used by Minio."
  value       = module.s3.s3.public_bucket
  sensitive   = true
}

output "minio_private_bucket" {
  description = "The private bucket used by Minio."
  value       = module.s3.s3.private_bucket
  sensitive   = true
}

output "bastion_public_dns" {
  description = "The URL for the bastion server."
  value       = module.bastion.connection.bastion_dns
  sensitive   = true
}

output "bastion_private_key" {
  description = "The private key for the bastion."
  value       = module.bastion.connection.private_key
  sensitive   = true
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.cluster.eks_cluster.name
}

locals {
  db_info = [for r in module.postgres.rds : r][0]
}

output "paragon_config" {
  description = "Required configuration for Paragon deployment"
  sensitive   = true
  value       = <<OUTPUT
    MINIO_ROOT_USER: ${module.s3.s3.access_key_id}
    MINIO_ROOT_PASSWORD: ${module.s3.s3.access_key_secret}
    MINIO_MICROSERVICE_USER: ${module.s3.s3.minio_microservice_user}
    MINIO_MICROSERVICE_PASS: ${module.s3.s3.minio_microservice_pass}
    MINIO_PUBLIC_BUCKET: ${module.s3.s3.public_bucket}
    MINIO_SYSTEM_BUCKET: ${module.s3.s3.private_bucket}

    POSTGRES_HOST: ${local.db_info.host}
    POSTGRES_PORT: ${local.db_info.port}
    POSTGRES_USER: ${local.db_info.user}
    POSTGRES_PASSWORD: ${local.db_info.password == null ? "" : local.db_info.password}
    POSTGRES_DATABASE: ${local.db_info.database}

    REDIS_HOST: ${module.redis.elasticache.cache.host}
    REDIS_PORT: ${module.redis.elasticache.cache.port}
  OUTPUT
}
