data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_security_group" "bastion" {
  name = "${var.workspace}-bastion-host"
}
