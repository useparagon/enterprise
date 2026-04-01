data "aws_iam_policy_document" "eso_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.eso_namespace}:${local.eso_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.workspace}-eso"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json

  tags = {
    Name = "${var.workspace}-eso"
  }
}

data "aws_iam_policy_document" "eso_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = length(var.secrets_manager_secret_arns) > 0 ? var.secrets_manager_secret_arns : ["arn:aws:secretsmanager:${var.aws_region}:*:secret:paragon/${var.workspace}/*"]
  }
}

resource "aws_iam_role_policy" "eso_secrets" {
  name   = "eso-secrets-access"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso_secrets.json
}
