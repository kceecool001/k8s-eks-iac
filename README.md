# EKS Terraform Infrastructure

Production-ready, modular Terraform code for deploying an Amazon EKS cluster in `eu-central-1` with a full DevSecOps CI/CD pipeline.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                     VPC (10.0.0.0/16)               │
│                                                     │
│  ┌──────────────┐          ┌──────────────┐         │
│  │  Public AZ-a │          │  Public AZ-b │         │
│  │  (IGW route) │          │  (IGW route) │         │
│  └──────┬───────┘          └──────┬───────┘         │
│         │ NAT GW                  │ NAT GW           │
│  ┌──────▼───────┐          ┌──────▼───────┐         │
│  │ Private AZ-a │          │ Private AZ-b │         │
│  │  EKS Nodes   │          │  EKS Nodes   │         │
│  └──────────────┘          └──────────────┘         │
└─────────────────────────────────────────────────────┘
                        │
              ┌─────────▼─────────┐
              │   EKS Control     │
              │   Plane v1.29     │
              │  (private+public  │
              │   endpoint)       │
              └───────────────────┘
```

## Module Structure

```
.
├── main.tf                     # Root module — wires all modules + aws-auth + addons
├── variables.tf                # Root input variables
├── outputs.tf                  # Root outputs
├── locals.tf                   # cluster_name + common_tags
├── versions.tf                 # Provider config + S3 remote state backend
├── terraform.tfvars.example    # Safe template — copy to terraform.tfvars
├── github-oidc.tf              # One-time bootstrap: GitHub Actions OIDC IAM role
└── modules/
    ├── vpc/                    # VPC, subnets, IGW, NAT gateways, route tables
    ├── eks/                    # EKS cluster, IAM roles, OIDC provider, RBAC roles
    │   ├── main.tf             # Cluster + security group
    │   ├── rbac.tf             # OIDC provider + admin/developer/readonly IAM roles
    │   └── addons.tf           # kube-proxy, vpc-cni (DaemonSets — node-independent)
    └── node_group/             # Managed node group + IAM role
```

## What Gets Provisioned

### Networking (`modules/vpc`)
- VPC with DNS hostnames enabled
- 2 public + 2 private subnets across `eu-central-1a` and `eu-central-1b`
- Internet Gateway + 2 NAT Gateways (one per AZ)
- Route tables with EKS subnet discovery tags

### EKS Cluster (`modules/eks`)
- EKS v1.29 with private + public endpoint access
- Public endpoint locked to `cluster_endpoint_public_access_cidrs`
- Control plane egress scoped to VPC CIDR only (ports 443 + 10250)
- OIDC provider for IRSA (pod-level IAM)
- 3 tiered RBAC IAM roles:

  | Role | Kubernetes Group | Access |
  |---|---|---|
  | `<cluster>-eks-admin` | `system:masters` | Full cluster-admin |
  | `<cluster>-eks-developer` | `eks:developers` | Namespaced — bind via K8s manifests |
  | `<cluster>-eks-readonly` | `eks:viewers` | View-only — bind via K8s manifests |

### Node Group (`modules/node_group`)
- Managed node group in private subnets only
- `t3.medium` SPOT instances (min=1, desired=2, max=3)
- IAM role with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`

### Addons (root `main.tf`)
| Addon | Type | Provisioned after |
|---|---|---|
| `kube-proxy` | DaemonSet | EKS cluster ready |
| `vpc-cni` | DaemonSet | EKS cluster ready |
| `coredns` | Deployment | Node group ready |
| `aws-ebs-csi-driver` | Deployment | Node group ready |

### RBAC (`aws-auth` ConfigMap — root `main.tf`)
Maps node group role + 3 tiered IAM roles into Kubernetes RBAC groups. Extensible via `aws_auth_roles` in `terraform.tfvars`.

### Remote State
S3 backend with encryption and state locking enabled.

---

## CI/CD Pipeline (GitHub Actions)

```
PR opened                     Merge to main              Manual
     │                              │                       │
     ▼                              ▼                       ▼
┌─────────┐                  ┌─────────────┐        ┌──────────────┐
│  Plan   │                  │    Apply    │        │   Destroy    │
│         │                  │             │        │              │
│Gitleaks │                  │ Gitleaks    │        │ Confirmation │
│Checkov  │                  │ Checkov     │        │ input gate   │
│fmt/init │                  │ init/plan   │        │ Audit log    │
│validate │                  │ apply       │        │ destroy      │
│plan     │                  │             │        │              │
│PR comment│                 │ Drift detect│        └──────────────┘
└─────────┘                  │ (scheduled) │
                             └─────────────┘
```

### Security controls in every pipeline run
- **Gitleaks** — scans full git history for committed secrets before AWS credentials are configured
- **Checkov** — IaC static analysis against CIS/NIST/AWS Well-Architected rules; results posted to GitHub Security tab as SARIF
- **OIDC authentication** — no long-lived AWS keys; GitHub exchanges a short-lived token for scoped temporary credentials
- **Pinned action SHAs** — all `uses:` references are pinned to commit SHAs to prevent supply chain attacks
- **Drift detection** — scheduled daily plan (Mon–Fri 06:00 UTC); opens a GitHub issue if out-of-band changes are detected
- **Audit trail on destroy** — requires typed confirmation + reason; both logged permanently in the job

---

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- kubectl

## First-Time Setup

### 1. Bootstrap GitHub Actions OIDC (run once locally)

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

terraform init
terraform apply -target=aws_iam_role.github_actions
```

Copy the `github_actions_role_arn` output value.

### 2. Add GitHub secret

In **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN from step 1 |

### 3. Enable GitHub Security tab

**Settings → Code security → Code scanning** — enables Checkov SARIF findings to appear inline on PRs.

### 4. Configure branch protection on `main`

- Require pull request before merging
- Require status checks: `Security Scan`, `Terraform Plan`
- Require branches to be up to date

---

## Local Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

### Configure kubectl after apply

```bash
aws eks update-kubeconfig --region eu-central-1 --name <cluster-name>
```

---

## Outputs

| Output | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Kubernetes API endpoint |
| `kubeconfig_command` | Full `aws eks update-kubeconfig` command |
| `node_group_arn` | Node group ARN |
| `oidc_provider_arn` | OIDC provider ARN for IRSA |
| `eks_admin_role_arn` | Admin IAM role ARN |
| `eks_developer_role_arn` | Developer IAM role ARN |
| `eks_readonly_role_arn` | Read-only IAM role ARN |
| `ebs_csi_driver_role_arn` | EBS CSI driver IRSA role ARN |
| `vpc_id` | VPC ID |

---

## Files Not Committed to Git

| File / Directory | Reason |
|---|---|
| `terraform.tfvars` | Contains real IPs and environment-specific values |
| `.terraform/` | Local provider cache and module downloads |
| `*.tfstate`, `*.tfstate.*` | State files — managed remotely in S3 |
| `.terraform.lock.hcl` | Lock file — can cause conflicts across machines |
| `*.tfplan` | Plan artefacts — may contain sensitive resource data |
| `crash.log` | Terraform crash logs |
| `checkov.sarif` | Scan artefact generated at runtime |
| `plan_output.txt` | Plan artefact generated at runtime |

Use `terraform.tfvars.example` as the committed template.

---

## Clean Up

```bash
# Via pipeline (recommended — creates audit trail)
# Trigger terraform-destroy workflow in GitHub Actions

# Or locally
terraform destroy
```
