resource "aws_security_group" "msk" {
  name_prefix = "${var.workspace}-msk"
  description = "Security access rules for msk."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound traffic from services in the private subnet on port 9094."
    from_port   = 80
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = var.private_subnet.*.cidr_block
  }

  egress {
    description = "Allow all outbound traffic."
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
