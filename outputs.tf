output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = module.node_group.node_group_arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = module.node_group.node_group_status
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_admin_role_arn" {
  description = "IAM role ARN for EKS admins"
  value       = module.eks.eks_admin_role_arn
}

output "eks_developer_role_arn" {
  description = "IAM role ARN for EKS developers"
  value       = module.eks.eks_developer_role_arn
}

output "eks_readonly_role_arn" {
  description = "IAM role ARN for EKS read-only users"
  value       = module.eks.eks_readonly_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver"
  value       = module.eks.ebs_csi_driver_role_arn
}
