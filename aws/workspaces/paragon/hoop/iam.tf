# IAM role for Hoop agent ServiceAccount with read-only access (IRSA)
resource "aws_iam_role" "hoop_support" {
  count = var.hoop_enabled && var.eks_oidc_provider_arn != null ? 1 : 0

  name = "${var.workspace}-hoop-support"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace_paragon.id}:hoopagent"
            "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.workspace}-hoop-support"
  }
}

resource "aws_iam_role_policy_attachment" "hoop_support" {
  count = var.hoop_enabled && var.eks_oidc_provider_arn != null ? 1 : 0

  role       = aws_iam_role.hoop_support[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
