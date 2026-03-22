# GitHub Actions OIDC IAM Role
# Apply this ONCE manually (terraform apply -target=aws_iam_role.github_actions)
# before the pipeline runs for the first time.
# After that the pipeline authenticates via OIDC — no static keys needed.

variable "github_org" {
  description = "GitHub organisation or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# GitHub's OIDC provider — already exists globally in AWS, just needs to be
# registered in your account once.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM role assumed by GitHub Actions via OIDC
resource "aws_iam_role" "github_actions" {
  name = "github-actions-eks-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringLike = {
          # Restricts to your specific repo — prevents other repos assuming this role
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "GitHub Actions OIDC"
  }
}

# Scoped policy — least-privilege permissions for managing this EKS project
resource "aws_iam_role_policy" "github_actions" {
  name = "github-actions-eks-terraform-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::eks-tfstate-kceetf",
          "arn:aws:s3:::eks-tfstate-kceetf/*"
        ]
      },
      {
        Sid    = "EKSManagement"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster", "eks:DeleteCluster", "eks:DescribeCluster",
          "eks:ListClusters", "eks:UpdateClusterConfig", "eks:UpdateClusterVersion",
          "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion",
          "eks:CreateAddon", "eks:DeleteAddon", "eks:DescribeAddon", "eks:UpdateAddon",
          "eks:TagResource", "eks:UntagResource",
          "eks:AssociateIdentityProviderConfig", "eks:DescribeIdentityProviderConfig",
          "eks:DisassociateIdentityProviderConfig", "eks:ListIdentityProviderConfigs",
          "eks:CreateAccessEntry", "eks:DeleteAccessEntry", "eks:DescribeAccessEntry"
        ]
        Resource = "arn:aws:eks:eu-central-1:*:cluster/*"
      },
      {
        Sid    = "EC2VPCWrite"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate"
        ]
        Resource = "arn:aws:ec2:eu-central-1:*:*"
      },
      {
        Sid    = "EC2VPCDescribe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeInternetGateways",
          "ec2:DescribeAddresses", "ec2:DescribeNatGateways", "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups", "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeAccountAttributes",
          "ec2:DescribeInstances", "ec2:DescribeLaunchTemplates"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:PassRole", "iam:TagRole", "iam:UntagRole"
        ]
        Resource = "arn:aws:iam::*:role/*-eks-*"
      },
      {
        Sid    = "IAMOIDCManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider"
        ]
        Resource = "arn:aws:iam::*:oidc-provider/*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus", "kms:ListResourceTags",
          "kms:EnableKeyRotation", "kms:ScheduleKeyDeletion",
          "kms:CreateAlias", "kms:DeleteAlias", "kms:ListAliases",
          "kms:TagResource", "kms:UntagResource"
        ]
        Resource = [
          "arn:aws:kms:eu-central-1:*:key/*",
          "arn:aws:kms:eu-central-1:*:alias/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:TagLogGroup", "logs:ListTagsLogGroup"
        ]
        Resource = "arn:aws:logs:eu-central-1:*:log-group:/aws/*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "Set this as AWS_ROLE_ARN in GitHub Actions secrets"
  value       = aws_iam_role.github_actions.arn
}
