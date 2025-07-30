locals {
  postgres_family = "postgres${split(".", var.rds_postgres_version)[0]}" // e.g. `postgres11`, `postgres12`, etc
}

resource "random_string" "postgres_root_username" {
  for_each = local.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = {
    for key, value in local.postgres_instances :
    key => value
    if try(var.migrated_passwords[key], null) == null
  }

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "random_string" "snapshot_identifier" {
  count = var.rds_final_snapshot_enabled ? 1 : 0

  length  = 8
  numeric = false
  special = false
  lower   = true
  upper   = false
}

resource "aws_db_subnet_group" "postgres" {
  name        = "${var.workspace}-postgres-subnet"
  description = "${var.workspace} postgres subnet group"
  subnet_ids  = var.private_subnet.*.id

  tags = {
    Name = "${var.workspace}-postgres-subnet"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.workspace}-${local.postgres_family}"
  family = local.postgres_family

  dynamic "parameter" {
    for_each = [
      {
        name         = "log_statement"
        value        = "ddl"
        apply_method = "pending-reboot"
      },
      {
        name         = "log_min_duration_statement"
        value        = 1000
        apply_method = "pending-reboot"
      },
      {
        name         = "max_connections"
        value        = 10000
        apply_method = "pending-reboot"
      },
      {
        name         = "wal_buffers"
        value        = "2048" # sets `wal_buffers` to 16mb
        apply_method = "pending-reboot"
      },
    ]
    content {
      apply_method = lookup(parameter.value, "apply_method", null)
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-postgres-group"
  }
}

data "aws_db_snapshot" "postgres" {
  for_each = var.rds_restore_from_snapshot ? local.postgres_instances : {}

  db_instance_identifier = each.value.name
  most_recent            = true
}

resource "aws_db_instance" "postgres" {
  for_each = local.postgres_instances

  identifier = each.value.name
  db_name    = each.value.db
  port       = "5432"
  username   = var.rds_restore_from_snapshot ? null : random_string.postgres_root_username[each.key].result
  password   = var.rds_restore_from_snapshot ? null : try(var.migrated_passwords[each.key], random_password.postgres_root_password[each.key].result)

  engine               = "postgres"
  engine_version       = var.rds_postgres_version
  instance_class       = each.value.size
  parameter_group_name = aws_db_parameter_group.postgres.name
  storage_type         = "gp3"

  allocated_storage           = 20
  max_allocated_storage       = 1000
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  availability_zone           = var.rds_multi_az ? null : var.availability_zones.names[0]
  backup_retention_period     = 7
  backup_window               = "06:00-07:00"
  ca_cert_identifier          = "rds-ca-rsa2048-g1"
  maintenance_window          = "Tue:04:00-Tue:05:00"
  monitoring_interval         = 15
  monitoring_role_arn         = aws_iam_role.rds_enhanced_monitoring.arn
  multi_az                    = var.rds_multi_az

  db_subnet_group_name      = aws_db_subnet_group.postgres.id
  deletion_protection       = !var.disable_deletion_protection
  snapshot_identifier       = var.rds_restore_from_snapshot ? data.aws_db_snapshot.postgres[each.key].id : null
  skip_final_snapshot       = !var.rds_final_snapshot_enabled
  final_snapshot_identifier = var.rds_final_snapshot_enabled ? "${each.value.name}-${random_string.snapshot_identifier[0].result}" : null
  publicly_accessible       = false
  storage_encrypted         = true
  vpc_security_group_ids    = [aws_security_group.postgres.id]

  performance_insights_enabled          = true
  performance_insights_retention_period = 31
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  apply_immediately = true
}
