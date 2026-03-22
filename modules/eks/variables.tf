variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

# Restricts which CIDRs can reach the public Kubernetes API endpoint.
# Set to your VPN/office CIDR in staging; tighten further or disable public access in prod.
variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDRs allowed to reach the EKS public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"] # override in tfvars — never leave open in production
}

variable "vpc_cidr" {
  description = "VPC CIDR used to scope control-plane egress to the VPC only"
  type        = string
}

variable "cluster_kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption (CKV_AWS_58)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
