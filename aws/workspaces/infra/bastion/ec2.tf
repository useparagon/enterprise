# get latest image from list of official Canonical Ubuntu 22.04 AMIs
data "aws_ami" "bastion" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  bastion_name           = "${var.workspace}-bastion"
  only_cloudflare_tunnel = var.cloudflare_tunnel_enabled
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.workspace}-key"
  public_key = tls_private_key.bastion.public_key_openssh

  tags = {
    Name = "${var.workspace}-key-pair"
  }
}

resource "random_string" "bastion_id" {
  length  = 4
  special = false
  numeric = false
  lower   = true
  upper   = true
}

module "bastion" {
  source = "github.com/useparagon/terraform-aws-bastion?ref=fix%2FPARA-12122%2Fstandardize-naming"

  name = local.bastion_name

  # logging
  bucket_name     = local.bastion_name
  log_expiry_days = 365

  # networking
  auto_scaling_group_subnets = var.private_subnet.*.id
  cidrs                      = var.ssh_whitelist
  create_dns_record          = false
  create_elb                 = !local.only_cloudflare_tunnel
  elb_subnets                = var.public_subnet.*.id
  is_lb_private              = local.only_cloudflare_tunnel
  private_ssh_port           = local.ssh_port
  public_ssh_port            = local.ssh_port
  region                     = var.aws_region
  vpc_id                     = var.vpc_id

  # instance
  allow_ssh_commands           = true
  bastion_ami                  = data.aws_ami.bastion.id
  bastion_host_key_pair        = aws_key_pair.bastion.id
  bastion_iam_policy_name      = local.bastion_name
  bastion_iam_role_name        = local.bastion_name
  bastion_launch_template_name = substr(local.bastion_name, 0, 22)
  instance_type                = "t3.micro"

  # user data template
  extra_user_data_content = templatefile("${path.module}/../templates/bastion/bastion-startup.tpl.sh", {
    account_id      = var.cloudflare_tunnel_account_id,
    aws_account_id  = data.aws_caller_identity.current.account_id
    aws_region      = var.aws_region,
    bastion_role    = local.bastion_name,
    cluster_name    = var.eks_cluster_name,
    cluster_version = var.eks_k8s_version,
    tunnel_id       = local.tunnel_id,
    tunnel_name     = local.tunnel_domain,
    tunnel_secret   = local.tunnel_secret,
  })
}

# allow SSM Connect access
resource "aws_iam_role_policy_attachment" "ssm_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = local.bastion_name

  depends_on = [module.bastion]
}
