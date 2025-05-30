variable "uptime_api_token" {
  description = "API Token for setting up BetterStack Uptime monitors."
  type        = string
  default     = null
}

variable "uptime_company" {
  description = "The pretty company name to include in BetterStack Uptime monitors."
  type        = string
}

variable "uptime_policy" {
  description = "The name of the escalation policy to associate with BetterStack Uptime monitors."
  type        = string
  default     = "Standard Escalation Policy"
}

variable "uptime_regions" {
  description = "The regions to enable on the BetterStack Uptime monitors."
  type        = list(string)
  default     = ["as", "au", "eu", "us"]
}

variable "health_checker_microservice" {
  description = "The information about the health-checker microservice"
  type        = map(any)
}

locals {
  enabled = var.uptime_api_token != null
}
