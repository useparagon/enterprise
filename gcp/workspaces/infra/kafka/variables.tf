variable "workspace" {
  description = "Workspace prefix for resource names."
  type        = string
}

variable "region" {
  description = "GCP region for the Managed Kafka cluster (must be a supported Managed Kafka location)."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID."
  type        = string
}

variable "private_subnet_uri" {
  description = "URI of the private subnet for the cluster (projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME)."
  type        = string
}

variable "gmk_vcpu_count" {
  description = "Number of vCPUs for the GMK cluster (minimum 3 in GCP)."
  type        = number
  default     = 3
}

variable "gmk_memory_bytes" {
  description = "Memory to provision for the GMK cluster in bytes. Must be between 1 GiB and 8 GiB per vCPU (e.g. 6 GiB = 6442450944)."
  type        = number
}

variable "gmk_disk_size_gib" {
  description = "Disk size in GiB per broker for the GMK cluster. 100GB is the minimum size."
  type        = number
  default     = 100
}

variable "gmk_auto_rebalance" {
  description = "Whether to enable automatic partition rebalancing when scaling up."
  type        = bool
  default     = false
}

variable "gmk_kafka_version" {
  description = "Kafka version (informational; the service may use a fixed version)."
  type        = string
  default     = "3.7.1"
}

variable "gmk_sasl_mechanism" {
  description = "SASL mechanism: plain (module creates SA key and outputs in cluster_password) or oauthbearer (Workload Identity)."
  type        = string
  default     = "plain"

  validation {
    condition     = contains(["oauthbearer", "plain"], var.gmk_sasl_mechanism)
    error_message = "gmk_sasl_mechanism must be \"oauthbearer\" or \"plain\"."
  }
}

variable "gmk_sasl_plain_key_file_path" {
  description = "Optional path to your own Kafka SA key JSON for SASL/PLAIN. When empty, the module creates the key and outputs it in cluster_password."
  type        = string
  default     = ""
}

