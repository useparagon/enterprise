provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
  region     = var.aws_region
  default_tags {
    tags = {
      Name        = var.aws_workspace
      Creator     = "Terraform"
      Environment = var.environment
      Workspace   = var.aws_workspace
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_dns_api_token
}
