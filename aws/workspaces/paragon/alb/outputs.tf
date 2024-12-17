output "nameservers" {
  description = "The nameservers for the Route53 zone."
  value       = aws_route53_zone.paragon.name_servers
}

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate."
  value       = var.acm_certificate_arn == null ? module.acm_request_certificate[0].arn : var.acm_certificate_arn
}

output "alb_arn" {
  description = "The ARN of the application load balancer."
  value       = data.aws_lb.load_balancer.arn
}
