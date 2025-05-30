resource "aws_msk_cluster" "kafka" {
  cluster_name           = var.workspace
  kafka_version          = "4.0.0"
  number_of_broker_nodes = 3

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
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      scram = true
    }
    tls {
      certificate_authority_arns = []
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to ebs_volume_size in favor of autoscaling policy
      broker_node_group_info[0].storage_info[0].ebs_storage_info[0].volume_size,
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
default.replication.factor = 3
min.insync.replicas = 2
process.roles = broker,controller
controller.quorum.voters = 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
controller.listener.names = CONTROLLER
listeners = PLAINTEXT://:9092,CONTROLLER://:9093
listener.security.protocol.map = PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
inter.broker.listener.name = PLAINTEXT
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
