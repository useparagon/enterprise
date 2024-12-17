resource "aws_iam_user" "grafana" {
  count = var.grafana_aws_access_key_id == null && var.grafana_aws_secret_access_key == null ? 1 : 0

  name = "${var.workspace}-iam-grafana"
  path = "/env/"

  tags = {
    Name = "${var.workspace}-iam-grafana"
  }
}

resource "aws_iam_access_key" "grafana" {
  count = var.grafana_aws_access_key_id == null && var.grafana_aws_secret_access_key == null ? 1 : 0

  user = aws_iam_user.grafana[0].name
}

resource "aws_iam_user_policy" "grafana_ro" {
  count = var.grafana_aws_access_key_id == null && var.grafana_aws_secret_access_key == null ? 1 : 0

  name = "${var.workspace}-iam-grafana-policy"
  user = aws_iam_user.grafana[0].name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudwatch:DescribeInsightRules",
          "cloudwatch:GetDashboard",
          "cloudwatch:GetInsightRuleReport",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAnomalyDetectors",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:ListMetricStreams",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:ListDashboards",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricStream",
          "cloudwatch:GetMetricWidgetImage",
          "logs:DescribeLogGroups",
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "random_string" "grafana_admin_email_prefix" {
  count = var.grafana_admin_email == null && var.grafana_admin_password == null ? 1 : 0

  length  = 16
  special = false
  numeric = false
  lower   = true
  upper   = false
}

resource "random_string" "grafana_admin_password" {
  count = var.grafana_admin_email == null && var.grafana_admin_password == null ? 1 : 0

  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 0
  numeric     = true
  special     = false
  lower       = true
  upper       = true
}
