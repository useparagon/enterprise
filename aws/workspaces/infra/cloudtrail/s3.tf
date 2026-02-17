data "aws_caller_identity" "current" {}

locals {
  elb_account_id_region_map = {
    "us-east-1"      = "127311923021" // US East (N. Virginia)
    "us-east-2"      = "033677994240" // US East (Ohio)
    "us-west-1"      = "027434742980" // US West (N. California)
    "us-west-2"      = "797873946194" // US West (Oregon)
    "af-south-1"     = "098369216593" // Africa (Cape Town)
    "ca-central-1"   = "985666609251" // Canada (Central)
    "eu-central-1"   = "054676820928" // Europe (Frankfurt)
    "eu-west-1"      = "156460612806" // Europe (Ireland)
    "eu-west-2"      = "652711504416" // Europe (London)
    "eu-south-1"     = "635631232127" // Europe (Milan)
    "eu-west-3"      = "009996457667" // Europe (Paris)
    "eu-north-1"     = "897822967062" // Europe (Stockholm)
    "ap-east-1"      = "754344448648" // Asia Pacific (Hong Kong)
    "ap-northeast-1" = "582318560864" // Asia Pacific (Tokyo)
    "ap-northeast-2" = "600734575887" // Asia Pacific (Seoul)
    "ap-northeast-3" = "383597477331" // Asia Pacific (Osaka)
    "ap-southeast-1" = "114774131450" // Asia Pacific (Singapore)
    "ap-southeast-2" = "783225319266" // Asia Pacific (Sydney)
    "ap-south-1"     = "718504428378" // Asia Pacific (Mumbai)
    "me-south-1"     = "076674570225" // Middle East (Bahrain)
    "sa-east-1"      = "507241528517" // South America (São Paulo)
    "us-gov-west-1"  = "048591011584" // AWS GovCloud (US-West)
    "us-gov-east-1"  = "190560391635" // AWS GovCloud (US-East)
    "cn-north-1"     = "638102146993" // China (Beijing)
    "cn-northwest-1" = "037604701340" // China (Ningxia)
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = local.cloudtrail_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  target_bucket = aws_s3_bucket.cloudtrail.id
  target_prefix = "self/"
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = var.mfa_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": [
              "${var.master_guardduty_account_id == null || var.master_guardduty_account_id == data.aws_caller_identity.current.account_id ? "arn:aws:s3:::${local.cloudtrail_name}/cloudtrail/AWSLogs/*/*" : "arn:aws:s3:::${local.cloudtrail_name}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"}"
            ],
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${local.cloudtrail_name}"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.elb_account_id_region_map[var.aws_region]}:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${local.cloudtrail_name}/*-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${local.cloudtrail_name}/*-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${local.cloudtrail_name}"
        },

        {
            "Sid": "AllowSSLRequestsOnly",
            "Action": "s3:*",
            "Effect": "Deny",
            "Resource": [
                "arn:aws:s3:::${local.cloudtrail_name}",
                "arn:aws:s3:::${local.cloudtrail_name}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            },
            "Principal": "*"
        }
    ]
}
POLICY

  depends_on = [
    aws_s3_bucket_ownership_controls.cloudtrail,
  ]
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "abort-incomplete"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 7
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire"
    status = "Enabled"

    expiration {
      days = 365
    }
  }
}
