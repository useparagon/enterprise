resource "aws_security_group" "elasticache" {
  name_prefix = "${var.workspace}-elasticache"
  description = "Security access rules for Elasticache."
  vpc_id      = var.vpc.id

  ingress {
    description = "Allow inbound traffic from services in the public subnet on port 6379."
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.public_subnet.*.cidr_block
  }

  ingress {
    description = "Allow inbound traffic from services in the private subnet on port 6379."
    from_port   = 6379
    to_port     = 6379
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
    Name = "${var.workspace}-elasticache"
  }
}
