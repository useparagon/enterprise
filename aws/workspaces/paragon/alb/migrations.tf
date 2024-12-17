# v1.0.1 -> v1.0.2
# `module.alb.module.acm_request_certificate` was moved to `module.alb.module.acm_request_certificate[0]`
# used to allow conditionally creating cloudtrail resources
moved {
  from = module.acm_request_certificate
  to   = module.acm_request_certificate[0]
}
