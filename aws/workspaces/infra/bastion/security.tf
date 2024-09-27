data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bastion_infra_read_only" {
  statement {
    sid = "BastionReadInfra"
    actions = [
      "autoscaling:Describe*",
      "autoscaling:Get*",
      "cloudformation:Describe*",
      "cloudformation:List*",
      "cloudformation:Get*",
      "ec2:Describe*",
      "ec2:Get*",
      "ecr:Describe*",
      "ecr:BatchGet*",
      "ecr:Get*",
      "ecr:List*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "ssm:Get*",
      "kms:Describe*",
      "kms:Get*",
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_role" "bastion" {
  name = var.workspace

  depends_on = [
    module.bastion
  ]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "BastionAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    resources = [
      # TODO: get from eks outputs
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
    ]
  }
}

resource "aws_iam_policy" "bastion_infra_read_only" {
  name   = "${var.workspace}-bastion-infra-read-only"
  policy = data.aws_iam_policy_document.bastion_infra_read_only.json
}

resource "aws_iam_policy" "assume_role" {
  name   = "${var.workspace}-assume-role"
  policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${var.workspace}-assume-role"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_infra_read_only" {
  policy_arn = aws_iam_policy.bastion_infra_read_only.arn
  role       = var.workspace
}

resource "aws_iam_role_policy_attachment" "assume_role" {
  policy_arn = aws_iam_policy.assume_role.arn
  role       = var.workspace
}
