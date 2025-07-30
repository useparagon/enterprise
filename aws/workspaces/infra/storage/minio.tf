resource "random_string" "minio_microservice_user" {
  length  = 10
  special = false
  numeric = true
  lower   = true
  upper   = false
}

resource "random_password" "minio_microservice_pass" {
  count = try(var.migrated_passwords.minio, null) == null ? 1 : 0

  length  = 16
  special = false
  numeric = true
  lower   = true
  upper   = true
}
