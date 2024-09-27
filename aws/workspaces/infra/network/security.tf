data "aws_caller_identity" "current" {}

resource "aws_iam_role" "vpc_flow_logs" {
  name_prefix = "${var.workspace}-vpc-logs"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowFlowLogsToS3",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "vpc-flow-logs.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name_prefix = "${var.workspace}-vpc-logs"
  role        = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AWSLogDeliveryWrite",
          "Effect" : "Allow",
          "Action" : "s3:PutObject",
          "Resource" : "${aws_s3_bucket.flow_logs.arn}/*",
          "Condition" : {
            "StringEquals" : {
              "aws:SourceAccount" : data.aws_caller_identity.current.account_id,
              "s3:x-amz-acl" : "bucket-owner-full-control"
            }
          }
        },
        {
          "Sid" : "AWSLogDeliveryAclCheck",
          "Effect" : "Allow",
          "Action" : [
            "s3:GetBucketAcl",
            "s3:ListBucket"
          ],
          "Resource" : aws_s3_bucket.flow_logs.arn,
          "Condition" : {
            "StringEquals" : {
              "aws:SourceAccount" : data.aws_caller_identity.current.account_id
            }
          }
          }, {
          "Sid" : "AWSLogKMSKeys",
          "Effect" : "Allow",
          "Action" : [
            "kms:Encrypt*",
            "kms:Decrypt*",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:Describe*"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}
