# KMS key for EKS secrets encryption (CKV_AWS_58)
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption — ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

# VPC Module - Creates networking infrastructure
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  common_tags        = local.common_tags
}

# EKS Module - Creates EKS cluster, IAM roles, OIDC provider, and RBAC IAM roles
module "eks" {
  source = "./modules/eks"

  cluster_name                         = local.cluster_name
  eks_version                          = var.eks_version
  subnet_ids                           = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  vpc_id                               = module.vpc.vpc_id
  vpc_cidr                             = var.vpc_cidr
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_kms_key_arn                  = aws_kms_key.eks.arn
  common_tags                          = local.common_tags

  depends_on = [module.vpc]
}

# Node Group Module - Creates managed worker nodes
module "node_group" {
  source = "./modules/node_group"

  cluster_name    = module.eks.cluster_name
  node_group_name = "${local.cluster_name}-node-group"
  subnet_ids      = module.vpc.private_subnet_ids
  instance_types  = [var.node_instance_type]
  capacity_type   = var.node_capacity_type
  min_size        = var.node_group_min_size
  max_size        = var.node_group_max_size
  desired_size    = var.node_group_desired_size
  common_tags     = local.common_tags

  depends_on = [module.eks]
}

# aws-auth ConfigMap — lives at root to avoid a cycle between eks and node_group modules.
# Both module outputs are fully resolved here before this resource is evaluated.
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  force = true

  data = {
    mapRoles = yamlencode(concat(
      # Node group role — required so worker nodes can register with the cluster
      [{
        rolearn  = module.node_group.node_group_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }],
      # Admin — full cluster-admin via system:masters
      [{
        rolearn  = module.eks.eks_admin_role_arn
        username = "eks-admin"
        groups   = ["system:masters"]
      }],
      # Developer — bind to namespaced Role via Kubernetes RBAC manifests
      [{
        rolearn  = module.eks.eks_developer_role_arn
        username = "eks-developer"
        groups   = ["eks:developers"]
      }],
      # Read-only — bind to view ClusterRole via Kubernetes RBAC manifests
      [{
        rolearn  = module.eks.eks_readonly_role_arn
        username = "eks-readonly"
        groups   = ["eks:viewers"]
      }],
      # Extra roles from tfvars (CI/CD pipelines, external teams, etc.)
      var.aws_auth_roles
    ))
  }

  depends_on = [module.eks, module.node_group]
}

# coredns and ebs_csi_driver run Deployment/pods that must be scheduled on nodes.
# Placing them here ensures nodes are Ready before EKS waits for ACTIVE status.
# Without this ordering both addons stay DEGRADED and Terraform times out.
resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.common_tags

  depends_on = [module.node_group]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = module.eks.ebs_csi_driver_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.common_tags

  depends_on = [module.node_group]
}
