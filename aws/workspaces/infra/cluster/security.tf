resource "aws_iam_role" "eks_cluster_admin" {
  name = "${var.workspace}-eks-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = local.eks_admin_arns
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "eks_cluster_admin" {
  name   = "${var.workspace}-eks-admin"
  policy = file("./templates/eks/eks-admin-policy.json")

  tags = {
    Name = "${var.workspace}-eks-admin"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_admin" {
  role       = aws_iam_role.eks_cluster_admin.name
  policy_arn = aws_iam_policy.eks_cluster_admin.arn
}

resource "aws_iam_role" "node_role" {
  name        = "${var.workspace}-eks-node-role"
  description = "role for eks node group"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "",
        Effect : "Allow",
        Principal : {
          Service : "ec2.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "eks_worker_policy" {
  name        = "${var.workspace}-eks-worker-policy"
  description = "Worker policy for the ALB Ingress."
  policy      = file("./templates/eks/eks-worker-policy.json")

  tags = {
    Name = "${var.workspace}-eks-worker-policy"
  }
}

resource "aws_iam_role_policy_attachment" "custom_worker_policy_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = aws_iam_policy.eks_worker_policy.arn
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

module "aws_ebs_csi_driver_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.48.0"

  create_role      = true
  role_description = "EBS CSI Driver Role"
  role_name_prefix = "${var.workspace}-eks-csi-"
  provider_url     = module.eks.oidc_provider

  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]

  oidc_fully_qualified_audiences = [
    "sts.amazonaws.com"
  ]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:ebs-csi-controller-sa"
  ]
}

# Annotate the Kubernetes service account to use the IAM Role
resource "kubernetes_service_account" "ebs_csi_controller" {
  automount_service_account_token = true

  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_ebs_csi_driver_iam_role.iam_role_arn
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
