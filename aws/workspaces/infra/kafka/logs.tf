# CloudWatch Log Group for MSK logs
resource "aws_cloudwatch_log_group" "kafka" {
  name              = "/aws/msk/${var.workspace}"
  retention_in_days = 30
}
