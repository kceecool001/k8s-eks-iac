variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for node group"
  type        = list(string)
}

variable "instance_types" {
  description = "List of instance types for node group"
  type        = list(string)
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "capacity_type" {
  description = "Capacity type for node group: ON_DEMAND or SPOT"
  type        = string
  default     = "SPOT"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
