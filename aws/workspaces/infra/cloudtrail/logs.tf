# https://github.com/trussworks/terraform-aws-cloudtrail
module "aws_cloudtrail" {
  source  = "trussworks/cloudtrail/aws"
  version = "5.2.0"

  s3_bucket_name            = aws_s3_bucket.cloudtrail.id
  log_retention_days        = 365
  org_trail                 = var.master_guardduty_account_id == null || var.master_guardduty_account_id == data.aws_caller_identity.current.account_id
  trail_name                = local.cloudtrail_name
  cloudwatch_log_group_name = local.cloudwatch_log_group_name
  iam_policy_name           = "${var.workspace}-cloudtrail-logs-policy"
  iam_role_name             = "${var.workspace}-cloudtrail-logs-role"
}
