resource "aws_iam_role" "rds_enhanced_monitoring" {
  name_prefix           = substr("${var.workspace}-rds", 0, 38)
  description           = "${var.workspace} rds monitor"
  assume_role_policy    = data.aws_iam_policy_document.rds_enhanced_monitoring.json
  force_detach_policies = true

  tags = {
    Name = "${var.workspace}-rds-monitor"
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_security_group" "postgres" {
  name_prefix = "${var.workspace}-postgres"
  description = "Security access rules for Postgres."
  vpc_id      = var.vpc.id

  ingress {
    description = "Allow inbound traffic from services in the public subnet on port 5432."
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.public_subnet.*.cidr_block
  }

  ingress {
    description = "Allow inbound traffic from services in the private subnet on port 5432."
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_subnet.*.cidr_block
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-postgres-security-group"
  }
}
