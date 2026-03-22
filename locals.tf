locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
