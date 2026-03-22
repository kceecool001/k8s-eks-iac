project_name = "agentxport"
environment  = "stage"
aws_region   = "eu-central-1"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-central-1a", "eu-central-1b"]

# EKS Configuration
eks_version = "1.29"

# Restrict API server access to your VPN/office CIDR — never leave as 0.0.0.0/0 in production
# Replace with your actual VPN or bastion IP range e.g. "203.0.113.0/24"
cluster_endpoint_public_access_cidrs = ["46.232.159.83/32"] # TODO: replace with your VPN/office CIDR

# Node Group Configuration — t3.medium is the minimum viable for EKS system pods + workloads
# SPOT cuts cost by ~60-70% vs ON_DEMAND; acceptable for lab/staging (interruptions are tolerable)
node_instance_type      = "t3.medium"
node_capacity_type      = "SPOT"
node_group_min_size     = 1
node_group_max_size     = 3
node_group_desired_size = 2
