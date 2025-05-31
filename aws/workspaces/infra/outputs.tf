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

output "kafka" {
  description = "Connection info for Kafka."
  value = var.managed_sync_enabled ? {
    cluster_bootstrap_brokers = split(",", module.kafka[0].cluster_bootstrap_brokers_sasl_scram)
  } : {}
  sensitive = true
}

output "logs_bucket" {
  description = "The bucket used to store system logs."
  value       = module.storage.s3.logs_bucket
  sensitive   = true
}

output "minio" {
  description = "MinIO server connection info."
  value = {
    public_bucket       = module.storage.s3.public_bucket
    private_bucket      = module.storage.s3.private_bucket
    managed_sync_bucket = module.storage.s3.managed_sync_bucket
    microservice_user   = module.storage.s3.minio_microservice_user
    microservice_pass   = module.storage.s3.minio_microservice_pass
    root_user           = module.storage.s3.access_key_id
    root_password       = module.storage.s3.access_key_secret
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
