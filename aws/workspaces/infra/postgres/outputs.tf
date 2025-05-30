output "rds" {
  value = {
    for key, value in local.postgres_instances :
    key => {
      host     = aws_db_instance.postgres[key].address
      port     = aws_db_instance.postgres[key].port
      user     = aws_db_instance.postgres[key].username
      password = var.rds_restore_from_snapshot ? null : random_password.postgres_root_password[key].result
      database = aws_db_instance.postgres[key].db_name
    }
  }
  sensitive = true
}
