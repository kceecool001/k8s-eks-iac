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

# Scoped policy — only the permissions needed to manage this EKS project
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
          "eks:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2VPCManagement"
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy",
          "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:PassRole", "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider", "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider", "iam:TagRole", "iam:UntagRole"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "Set this as AWS_ROLE_ARN in GitHub Actions secrets"
  value       = aws_iam_role.github_actions.arn
}
