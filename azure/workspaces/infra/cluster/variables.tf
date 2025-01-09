variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "private_subnet" {
  description = "Private subnet accessible only within the virtual network to deploy to."
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
}

variable "k8s_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
}

variable "k8s_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
}

variable "k8s_sku_tier" {
  description = "The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`)."
  type        = string
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.k8s_sku_tier)
    error_message = "The sku_tier for the AKS cluster. It must be `Free`, `Standard`, or `Premium`."
  }
}
