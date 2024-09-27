variable "workspace" {
  description = "The name of the workspace resources are being created in."
}

variable "aws_region" {
  description = "The AWS region resources are created in."
}

variable "master_guardduty_account_id" {
  description = "Optional AWS account id to delegate GuardDuty control to."
  type        = string
}

variable "mfa_enabled" {
  description = "Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion)"
  type        = bool
}

variable "force_destroy" {
  description = "Whether to enable force destroy."
  type        = bool
}

locals {
  cloudtrail_name           = "${var.workspace}-cloudtrail"
  cloudwatch_log_group_name = "${var.workspace}-cloudtrail-events"
}
