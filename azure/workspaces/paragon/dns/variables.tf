variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Zone `DNS`"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id to set CNAMEs."
  type        = string
}

variable "domain" {
  description = "The domain used for the application. Used to generate an SSL certificate and associates CNAMEs."
  type        = string
}

variable "ingress_loadbalancer" {
  description = "The Ingress Load Balancer for our Microservices"
  type        = string
}

variable "public_services" {
  description = "The services exposed to the public internet."
  type = map(object({
    port       = number
    public_url = string
  }))
}
