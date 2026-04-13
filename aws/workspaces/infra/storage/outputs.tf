output "s3" {
  value = {
    access_key_id           = aws_iam_access_key.app.id
    access_key_secret       = aws_iam_access_key.app.secret
    private_bucket          = aws_s3_bucket.app.bucket
    public_bucket           = aws_s3_bucket.cdn.bucket
    auditlogs_bucket        = aws_s3_bucket.auditlogs.bucket
    logs_bucket             = aws_s3_bucket.logs.bucket
    managed_sync_bucket     = var.managed_sync_enabled ? aws_s3_bucket.managed_sync[0].bucket : null
    minio_microservice_user = random_string.minio_microservice_user.result
    minio_microservice_pass = random_password.minio_microservice_pass.result
  }
  sensitive = true
}
