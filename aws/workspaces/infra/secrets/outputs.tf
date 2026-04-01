output "secret_arns" {
  description = "ARNs of all Secrets Manager secrets created."
  value = compact([
    aws_secretsmanager_secret.env.arn,
    aws_secretsmanager_secret.docker_cfg.arn,
    try(aws_secretsmanager_secret.managed_sync[0].arn, ""),
    try(aws_secretsmanager_secret.openobserve[0].arn, ""),
  ])
}

output "env_secret_name" {
  description = "Name of the environment config secret in Secrets Manager."
  value       = aws_secretsmanager_secret.env.name
}

output "docker_cfg_secret_name" {
  description = "Name of the Docker config secret in Secrets Manager."
  value       = aws_secretsmanager_secret.docker_cfg.name
}

output "managed_sync_secret_name" {
  description = "Name of the managed sync secret in Secrets Manager (null if disabled)."
  value       = try(aws_secretsmanager_secret.managed_sync[0].name, null)
}

output "openobserve_secret_name" {
  description = "Name of the OpenObserve credentials secret in Secrets Manager (null if not created)."
  value       = try(aws_secretsmanager_secret.openobserve[0].name, null)
}
