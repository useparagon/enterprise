module "acm_request_certificate" {
  count   = var.certificate == null ? 1 : 0
  source  = "cloudposse/acm-request-certificate/aws"
  version = "0.17.0"

  domain_name                       = var.domain
  process_domain_validation_options = true
  ttl                               = "300"
  subject_alternative_names         = ["*.${var.domain}"]
  zone_id                           = aws_route53_zone.paragon.zone_id
}

# this has been required at times for certificate validation to succeed for alternate name
resource "aws_route53_record" "caa" {
  name    = var.domain
  records = ["0 issue \"amazon.com\""]
  ttl     = 300
  type    = "CAA"
  zone_id = aws_route53_zone.paragon.zone_id
}
