# CloudWatch Log Group for MSK logs
resource "aws_cloudwatch_log_group" "kafka" {
  name              = "/aws/msk/${var.workspace}"
  retention_in_days = 30
}

# S3 bucket for MSK logs
resource "aws_s3_bucket" "kafka_logs" {
  bucket        = "${var.workspace}-msk-logs"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "kafka_logs" {
  bucket = aws_s3_bucket.kafka_logs.id

  target_bucket = var.logs_bucket
  target_prefix = "s3/msk/"
}

resource "aws_s3_bucket_versioning" "kafka_logs" {
  bucket = aws_s3_bucket.kafka_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "kafka_logs" {
  bucket = aws_s3_bucket.kafka_logs.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "kafka_logs" {
  bucket = aws_s3_bucket.kafka_logs.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.kafka_logs
  ]
}

resource "aws_s3_bucket_public_access_block" "kafka_logs" {
  bucket = aws_s3_bucket.kafka_logs.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kafka_logs" {
  bucket = aws_s3_bucket.kafka_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
