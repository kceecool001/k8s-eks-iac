output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used for IRSA)"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (used for IRSA trust policies)"
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "eks_admin_role_arn" {
  description = "ARN of the EKS admin IAM role"
  value       = aws_iam_role.eks_admin.arn
}

output "eks_developer_role_arn" {
  description = "ARN of the EKS developer IAM role"
  value       = aws_iam_role.eks_developer.arn
}

output "eks_readonly_role_arn" {
  description = "ARN of the EKS read-only IAM role"
  value       = aws_iam_role.eks_readonly.arn
}

output "ebs_csi_driver_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}
