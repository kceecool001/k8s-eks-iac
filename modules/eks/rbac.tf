# OIDC Provider — enables IAM Roles for Service Accounts (IRSA).
# Pods assume scoped IAM roles directly instead of inheriting the node instance profile.
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.common_tags
}

data "aws_caller_identity" "current" {}

# ── IAM Roles per access tier ────────────────────────────────────────────────

resource "aws_iam_role" "eks_admin" {
  name = "${var.cluster_name}-eks-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role" "eks_developer" {
  name = "${var.cluster_name}-eks-developer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role" "eks_readonly" {
  name = "${var.cluster_name}-eks-readonly"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
    }]
  })

  tags = var.common_tags
}
