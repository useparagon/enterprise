resource "aws_s3_bucket" "auditlogs" {
  bucket              = "${var.workspace}-auditlogs"
  force_destroy       = var.force_destroy
  object_lock_enabled = var.auditlogs_lock_enabled
}

resource "aws_s3_bucket_logging" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/auditlogs/"
}

resource "aws_s3_bucket_ownership_controls" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "auditlogs" {
  count  = var.auditlogs_lock_enabled ? 1 : 0
  bucket = aws_s3_bucket.auditlogs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.auditlogs_retention_days
    }
  }
}

resource "aws_s3_bucket_acl" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.auditlogs
  ]
}

resource "aws_s3_bucket_public_access_block" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "auditlogs" {
  bucket = aws_s3_bucket.auditlogs.id

  rule {
    id = "expiration"

    expiration {
      days = var.app_bucket_expiration
    }

    noncurrent_version_expiration {
      noncurrent_days = var.app_bucket_expiration
    }

    status = "Enabled"
  }
}
