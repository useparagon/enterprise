variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the MSK cluster will be created"
  type        = string
}

variable "logs_bucket" {
  description = "Bucket to store system logs."
  type        = string
}

variable "force_destroy" {
  description = "Whether to enable force destroy."
  type        = bool
}

variable "private_subnet" {
  description = "The private subnets within the VPC."
}

variable "msk_instance_type" {
  description = "The instance type for the MSK cluster."
  type        = string
}

variable "msk_kafka_version" {
  description = "The Kafka version for the MSK cluster."
  type        = string
}
