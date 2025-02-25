resource "aws_s3_bucket" "cdn" {
  bucket        = "${var.workspace}-cdn"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_cors_configuration" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_logging" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/cdn/"
}

resource "aws_s3_bucket_ownership_controls" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "cdn" {
  bucket = aws_s3_bucket.cdn.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_ownership_controls.cdn
  ]
}

resource "aws_s3_bucket_public_access_block" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowAnonymousReads",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : [
          "s3:GetObjectVersion",
          "s3:GetObject"
        ],
        "Resource" : "arn:aws:s3:::${aws_s3_bucket.cdn.id}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.cdn
  ]
}
