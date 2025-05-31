resource "aws_s3_bucket" "app" {
  bucket        = "${var.workspace}-app"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "app" {
  bucket = aws_s3_bucket.app.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/app/"
}

resource "aws_s3_bucket_ownership_controls" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "app" {
  bucket = aws_s3_bucket.app.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.app
  ]
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

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

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "AllowSSLRequestsOnly"
    actions   = ["s3:*"]
    effect    = "Deny"
    resources = ["${aws_s3_bucket.app.arn}", "${aws_s3_bucket.app.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_user" "app" {
  name = "${var.workspace}-s3-user"

  tags = {
    Name = "${var.workspace}-s3-user"
  }
}

resource "aws_iam_access_key" "app" {
  user = aws_iam_user.app.name
}

resource "aws_iam_user_policy" "app" {
  name = "${var.workspace}-s3-policy"
  user = aws_iam_user.app.name

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowReadBucketOperations",
          "Action" : [
            "s3:GetBucketAcl",
            "s3:GetBucketCORS",
            "s3:GetBucketLocation",
            "s3:GetBucketPolicy",
            "s3:GetBucketVersioning",
            "s3:GetEncryptionConfiguration",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads"
          ],
          "Effect" : "Allow",
          "Resource" : concat([
            "${aws_s3_bucket.app.arn}",
            "${aws_s3_bucket.cdn.arn}"
            ], var.managed_sync_enabled ? [
            "${aws_s3_bucket.managed_sync[0].arn}"
          ] : [])
        },
        {
          "Sid" : "AllowReadObjectOperations",
          "Action" : [
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:GetObjectRetention",
            "s3:ListMultipartUploadParts"
          ],
          "Effect" : "Allow",
          "Resource" : concat([
            "${aws_s3_bucket.app.arn}/*",
            "${aws_s3_bucket.cdn.arn}/*"
            ], var.managed_sync_enabled ? [
            "${aws_s3_bucket.managed_sync[0].arn}/*"
          ] : [])
        },
        {
          "Sid" : "AllowPutAndDeleteObjectOperations",
          "Action" : [
            "s3:AbortMultipartUpload",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:PutObject",
            "s3:PutObjectLegalHold"
          ],
          "Effect" : "Allow",
          "Resource" : concat([
            "${aws_s3_bucket.app.arn}/*",
            "${aws_s3_bucket.cdn.arn}/*"
            ], var.managed_sync_enabled ? [
            "${aws_s3_bucket.managed_sync[0].arn}/*"
          ] : [])
        }
      ]
    }
  )
}
