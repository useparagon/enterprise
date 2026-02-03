# Required so Terraform uses hoophq/hoop instead of default hashicorp/hoop (which does not exist).
terraform {
  required_providers {
    hoop = {
      source  = "hoophq/hoop"
      version = ">= 0.0.19"
    }
  }
}
