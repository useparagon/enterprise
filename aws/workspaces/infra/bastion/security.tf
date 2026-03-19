data "aws_caller_identity" "current" {}

data "aws_iam_role" "bastion" {
  name = local.bastion_name

  depends_on = [
    module.bastion
  ]
}

# infrastructure read only role for bastion
data "aws_iam_policy_document" "bastion_infra_read_only" {
  statement {
    actions = [
      "acm:Describe*",
      "acm:Get*",
      "acm:List*",
      "autoscaling:Describe*",
      "autoscaling:Get*",
      "cloudformation:Describe*",
      "cloudformation:Get*",
      "cloudformation:List*",
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "ec2:Describe*",
      "ec2:Get*",
      "ecr:BatchGet*",
      "ecr:Describe*",
      "ecr:Get*",
      "ecr:List*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "ssm:Get*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "bastion_infra_read_only" {
  name   = "${local.bastion_name}-infra-read-only"
  policy = data.aws_iam_policy_document.bastion_infra_read_only.json

  tags = {
    Name = "${local.bastion_name}-infra-read-only"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_infra_read_only" {
  policy_arn = aws_iam_policy.bastion_infra_read_only.arn
  role       = data.aws_iam_role.bastion.name
}

# allow bastion to assume role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    resources = [
      data.aws_iam_role.bastion.arn
    ]
  }
}

resource "aws_iam_policy" "assume_role" {
  name   = "${local.bastion_name}-assume-role"
  policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${local.bastion_name}-assume-role"
  }
}

resource "aws_iam_role_policy_attachment" "assume_role" {
  policy_arn = aws_iam_policy.assume_role.arn
  role       = data.aws_iam_role.bastion.name
}
