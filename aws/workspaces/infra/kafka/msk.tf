resource "aws_kms_key" "kafka" {
  description = "KMS for AWS MSK data encryption"
  tags = {
    Name = "${var.workspace}-msk"
  }
}

resource "aws_kms_alias" "kafka_alias" {
  name          = "alias/${var.workspace}-msk"
  target_key_id = aws_kms_key.kafka.key_id
}

resource "random_string" "msk_username" {
  length           = 16
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "msk_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "msk_credentials" {
  name       = "AmazonMSK_${var.workspace}-credentials"
  kms_key_id = aws_kms_key.kafka.key_id
}

resource "aws_secretsmanager_secret_version" "msk_credentials" {
  secret_id = aws_secretsmanager_secret.msk_credentials.id
  secret_string = jsonencode({
    username  = random_string.msk_username.result
    password  = random_password.msk_password.result
    mechanism = "SCRAM-SHA-512"
  })
}

resource "aws_msk_scram_secret_association" "kafka" {
  cluster_arn     = aws_msk_cluster.kafka.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_credentials.arn]
}

resource "aws_msk_cluster" "kafka" {
  cluster_name           = var.workspace
  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = var.msk_kafka_num_broker_nodes

  broker_node_group_info {
    instance_type   = var.msk_instance_type
    client_subnets  = var.private_subnet.*.id
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.kafka.arn
    revision = aws_msk_configuration.kafka.latest_revision
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kafka.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }
  client_authentication {
    sasl {
      scram = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.kafka.name
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to ebs_volume_size in favor of autoscaling policy
      broker_node_group_info[0].storage_info[0].ebs_storage_info[0].volume_size,
      client_authentication[0].tls
    ]
  }
}

resource "aws_msk_configuration" "kafka" {
  name = "${var.workspace}-config"

  kafka_versions = [var.msk_kafka_version]

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
log.retention.hours = 168
num.partitions = 3
default.replication.factor = ${ceil(var.msk_kafka_num_broker_nodes / 2)}
min.insync.replicas = ${ceil(var.msk_kafka_num_broker_nodes / 2)}
PROPERTIES
}

resource "aws_appautoscaling_target" "kafka" {
  max_capacity       = 3000
  min_capacity       = 1
  resource_id        = aws_msk_cluster.kafka.arn
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  service_namespace  = "kafka"
}

resource "aws_appautoscaling_policy" "kafka" {
  name               = "${aws_msk_cluster.kafka.cluster_name}-msk-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_msk_cluster.kafka.arn
  scalable_dimension = aws_appautoscaling_target.kafka.scalable_dimension
  service_namespace  = aws_appautoscaling_target.kafka.service_namespace

  target_tracking_scaling_policy_configuration {
    disable_scale_in = false
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }

    target_value = 70
  }
}
