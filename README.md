# Terraform Drift Detection & Auto-Remediation System

> A production-grade infrastructure drift detection system with automated remediation, GitHub Actions pipelines, Slack alerts, and a real-time dashboard.

![Terraform](https://img.shields.io/badge/Terraform-v1.10.3-purple)
![AWS](https://img.shields.io/badge/AWS-ap--south--1-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 🧭 Problem Statement

Infrastructure drift occurs when:
- Someone changes AWS resources manually from the console
- External tools modify infrastructure
- Temporary fixes are made but never committed to code
- Security rules get altered unintentionally

**Without automated detection:**
- Terraform state becomes inaccurate
- Security risks remain unnoticed
- Infrastructure becomes unpredictable

**This project solves that by implementing:**
- ✅ Continuous drift detection (scheduled + on-demand)
- ✅ Automated remediation via `terraform apply`
- ✅ GitHub Issue tracking for audit trail
- ✅ Slack notifications for real-time alerts
- ✅ Multi-environment support (dev, preprod, prod)
- ✅ Real-time drift dashboard deployed on GitHub Pages

---

## 🏗️ Infrastructure Architecture

The project deploys an S3 bucket per environment with dynamic naming:

```hcl
resource "aws_s3_bucket" "main" {
  bucket = "drift-${data.aws_caller_identity.current.account_id}-${var.environment}"
}
```

**Key Features:**
- AWS Account ID-based unique bucket naming
- Environment-specific resources (dev/preprod/prod)
- Region: `ap-south-1` (Mumbai)
- Default resource tagging for governance

---

## 🌍 Environment Strategy

| Environment | Schedule | Auto-Remediation | Branch |
|-------------|----------|------------------|--------|
| **dev** | Every 5 minutes | ✅ Enabled | main |
| **preprod** | Every 5 minutes (after dev) | ✅ Enabled | main |
| **prod** | Manual trigger only | ✅ Enabled | main |

### Environment Variables
Each environment has its own tfvars file:
```
terraform/stage_variables/
├── dev/
│   └── ap-south-1.tfvars
├── preprod/
│   └── ap-south-1.tfvars
└── prod/
    └── ap-south-1.tfvars
```

---

## ⚙️ GitHub Actions Workflows

### 📁 Workflow Structure
```
.github/workflows/
├── terraform-core.yml      # Reusable core workflow (drift detection + remediation)
├── drift-nonprod.yml       # Scheduled drift detection for dev & preprod
├── drift-prod.yml          # Manual drift detection for prod
├── terraform-deploy.yml    # Manual infrastructure deployment with approval
├── terraform-destroy.yml   # Manual infrastructure teardown with approval
└── deploy-pages.yml        # Dashboard deployment to GitHub Pages
```

### 1️⃣ Drift Detection - NonProd (`drift-nonprod.yml`)

**Triggers:**
- 🕐 Scheduled: Every 5 minutes (`*/5 * * * *`)
- 🖱️ Manual: `workflow_dispatch`

**Flow:**
1. Runs `dev` environment first
2. Then runs `preprod` (sequential, `needs: dev`)

### 2️⃣ Drift Detection - Prod (`drift-prod.yml`)

**Triggers:**
- 🖱️ Manual only (`workflow_dispatch`)

**Why manual?** Production environments require explicit control to avoid unintended changes.

### 3️⃣ Core Workflow (`terraform-core.yml`)

The heart of drift detection, used as a reusable workflow:

```yaml
on:
  workflow_call:
    inputs:
      environment: { required: true, type: string }
      region: { required: true, type: string }
```

**Drift Detection Logic:**
```bash
terraform plan -detailed-exitcode
```

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| `0` | No drift | Close existing issues, update dashboard |
| `1` | Error | Fail workflow |
| `2` | Drift detected | Create GitHub issue, auto-apply, notify Slack |

**Key Steps:**
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Terraform init with S3 backend
4. Terraform plan with `-detailed-exitcode`
5. If drift: Create/update GitHub Issue
6. Auto-apply changes
7. Notify Slack (success or failure)
8. Update dashboard JSON
9. Commit dashboard changes

### 4️⃣ Deploy Workflow (`terraform-deploy.yml`)

**Triggers:** Manual with inputs
- Environment: `dev`, `preprod`, `prod`
- Region: `ap-south-1`

**Features:**
- Manual approval gate before apply
- Terraform plan artifact saved
- Safe, controlled deployments

### 5️⃣ Destroy Workflow (`terraform-destroy.yml`)

**Triggers:** Manual with inputs

**Safety Features:**
- Manual approval required
- Explicit environment selection
- Plan destroy before actual destruction

### 6️⃣ Dashboard Deployment (`deploy-pages.yml`)

**Triggers:**
- Push to `main` (dashboard changes)
- After drift workflows complete
- Manual dispatch

Deploys the drift dashboard to GitHub Pages.

---

## 🔐 Remote State Management

Terraform state is stored in S3:

```hcl
terraform {
  backend "s3" {}
}
```

**Backend Configuration (dynamic):**
```bash
terraform init \
  -backend-config="bucket=terraform-drift-005" \
  -backend-config="key=${environment}/${region}/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"
```

**State File Structure:**
```
s3://terraform-drift-005/
├── dev/ap-south-1/terraform.tfstate
├── preprod/ap-south-1/terraform.tfstate
└── prod/ap-south-1/terraform.tfstate
```

**Benefits:**
- ✅ Encryption enabled
- ✅ Native S3 locking (Terraform 1.10+)
- ✅ Separate state per environment
- ✅ No DynamoDB required

---

## 📊 Drift Dashboard

A real-time dashboard deployed on GitHub Pages showing:

- **Summary Cards:** Total environments, clean, drift, remediated counts
- **Per-Environment Details:**
  - Status (clean/drift/remediated/error)
  - Region
  - Drift count with resource breakdown
  - Apply outcome
  - Triggered by
  - Last checked timestamp
  - Link to workflow run

### Dashboard Files
```
dashboard/
├── index.html       # Dashboard UI
├── config.json      # Environment configuration
├── dev.json         # Dev environment status
├── preprod.json     # Preprod environment status
└── prod.json        # Prod environment status
```

### Sample Environment Status JSON
```json
{
  "environment": "preprod",
  "region": "ap-south-1",
  "status": "remediated",
  "drift_count": "2",
  "resources_to_add": "0",
  "resources_to_change": "2",
  "resources_to_destroy": "0",
  "apply_outcome": "success",
  "timestamp": "2026-02-14 17:56:49 IST",
  "workflow_url": "https://github.com/ravisrma/terraform-drift/actions/runs/22017293548",
  "triggered_by": "ravisrma"
}
```

---

## 📋 GitHub Issues = Audit Trail

Every drift event creates a tracked GitHub Issue:

**Labels Applied:**
- `drift-detection`
- `auto-fix`
- `{environment}` (dev/preprod/prod)

**Issue Lifecycle:**
1. 🚨 Drift detected → Issue created with plan details
2. 🔧 Auto-remediation attempted
3. ✅ Success → Issue closed with comment
4. ❌ Failure → Issue remains open, manual intervention required

---

## 📡 Slack Notifications

Real-time alerts sent via webhook:

**Success Message:**
```
✅ Drift Detected & Automatically Fixed
Repository: ravisrma/terraform-drift
Branch: main
Workflow: [View Run]
```

**Failure Message:**
```
❌ Drift Detected but Auto-Fix Failed
⚠️ Manual intervention required!
```

---

## 🔑 Required Secrets

Configure these in GitHub Repository Settings → Secrets:

| Secret | Description |
|--------|-------------|
| `AWS_ROLE` | IAM Role ARN for OIDC authentication |
| `SLACK_WEBHOOK` | Slack Incoming Webhook URL |
| `MY_GITHUB_TOKEN` | GitHub PAT for issue management & commits |

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/ravisrma/terraform-drift.git
cd terraform-drift
```

### 2. Configure AWS Backend
Create the S3 bucket for state storage:
```bash
aws s3 mb s3://terraform-drift-005 --region ap-south-1
```

### 3. Set GitHub Secrets
- Add `AWS_ROLE`, `SLACK_WEBHOOK`, and `MY_GITHUB_TOKEN`

### 4. Deploy Infrastructure
Run the **Deploy Terraform** workflow manually:
- Select environment: `dev`
- Approve the deployment

### 5. Test Drift Detection
1. Manually modify the S3 bucket in AWS Console
2. Run the **Drift NonProd** workflow
3. Watch the auto-remediation in action!

---

## 📁 Project Structure

```
terraform-drift/
├── .github/workflows/
│   ├── terraform-core.yml      # Reusable drift detection workflow
│   ├── drift-nonprod.yml       # Scheduled: dev & preprod
│   ├── drift-prod.yml          # Manual: prod
│   ├── terraform-deploy.yml    # Deploy infrastructure
│   ├── terraform-destroy.yml   # Destroy infrastructure
│   └── deploy-pages.yml        # Dashboard deployment
├── terraform/
│   ├── main.tf                 # Main infrastructure (S3 bucket)
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── providers.tf            # AWS provider & backend config
│   ├── versions.tf             # Terraform version constraints
│   └── stage_variables/
│       ├── dev/ap-south-1.tfvars
│       ├── preprod/ap-south-1.tfvars
│       └── prod/ap-south-1.tfvars
├── dashboard/
│   ├── index.html              # Dashboard UI
│   ├── config.json             # Dashboard configuration
│   ├── dev.json                # Dev status
│   ├── preprod.json            # Preprod status
│   └── prod.json               # Prod status
└── README.md
```

---

## 🎯 Key Lessons & Best Practices

1. **Drift detection is essential** in shared cloud environments
2. **Automated remediation** dramatically reduces risk
3. **GitHub Issues** provide powerful audit visibility
4. **Remote state locking** prevents destructive race conditions
5. **Scheduled runs for non-prod**, manual for prod
6. **Real-time dashboards** provide instant visibility
7. **Slack notifications** ensure team awareness

---

## 💰 Cost Considerations

This demo uses minimal resources:
- S3 bucket (standard pricing)
- S3 backend storage (minimal)
- GitHub Actions (free tier for public repos)

**Tip:** Destroy unused environments with the **Destroy Terraform** workflow.

---

## 👤 Author

**Ravi Sharma** ([@ravisrma](https://github.com/ravisrma))

---

## 📄 License

MIT License - feel free to use and modify!
