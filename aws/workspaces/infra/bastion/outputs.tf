output "bucket" {
  value = module.bastion.bucket_name
}

output "connection" {
  value = {
    bastion_dns = var.cloudflare_tunnel_enabled ? local.tunnel_domain : module.bastion.elb_ip
    private_key = tls_private_key.bastion.private_key_pem
  }
}

output "security_group" {
  value = {
    host    = module.bastion.bastion_host_security_group
    private = module.bastion.private_instances_security_group
  }
}

output "bastion_role_arn" {
  value = data.aws_iam_role.bastion.arn
}
