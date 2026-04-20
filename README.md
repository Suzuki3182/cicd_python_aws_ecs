# cicd-python-aws-ecs

A **Python web API** that runs on **AWS ECS Fargate** (serverless containers), deployed automatically via **GitHub Actions** and managed with **Terraform** (infrastructure as code). Claude Code acts as an autonomous DevOps agent — it runs tests, scans for vulnerabilities, deploys, and rolls back without human intervention.

> **New to all this?** This README walks you through every step, explains every tool, and shows every command you need to run.

---

## Table of Contents

1. [What This Project Does](#1-what-this-project-does)
2. [How It All Fits Together](#2-how-it-all-fits-together)
3. [Repository Structure Explained](#3-repository-structure-explained)
4. [Prerequisites — Install Everything First](#4-prerequisites--install-everything-first)
5. [AWS Account Setup](#5-aws-account-setup)
6. [GitHub Repository Setup](#6-github-repository-setup)
7. [First-Time Bootstrap](#7-first-time-bootstrap)
8. [Running the App Locally](#8-running-the-app-locally)
9. [Deploying to Staging](#9-deploying-to-staging)
10. [Deploying to Production](#10-deploying-to-production)
11. [Understanding the CI/CD Pipelines](#11-understanding-the-cicd-pipelines)
12. [Makefile Cheat Sheet](#12-makefile-cheat-sheet)
13. [Claude Code Skills](#13-claude-code-skills)
14. [Troubleshooting](#14-troubleshooting)
15. [Teardown — Delete Everything](#15-teardown--delete-everything)

---

## 1. What This Project Does

This project takes a simple Python web app and automates the entire lifecycle:

```
You write code  →  Push to GitHub  →  GitHub Actions runs automatically:
  1. Checks code style (lint)
  2. Runs tests
  3. Builds a Docker image
  4. Scans for security vulnerabilities
  5. Deploys to AWS (staging first, then prod)
  6. Rolls back automatically if something breaks
```

**AWS services used:**

| Service | What it does | Why we use it |
|---------|-------------|---------------|
| ECS Fargate | Runs your Docker container | No servers to manage |
| ECR | Stores Docker images | Private container registry |
| ALB | Routes web traffic to containers | Load balancer + health checks |
| RDS Aurora | PostgreSQL database | Managed, auto-scaling database |
| S3 | File/artifact storage | Cheap, durable object storage |
| Secrets Manager | Stores passwords/API keys | Never hardcode credentials |
| CloudWatch | Logs and monitoring | See what's happening at all times |

---

## 2. How It All Fits Together

```
Your laptop
    │
    │  git push
    ▼
GitHub Repository
    │
    │  triggers automatically
    ▼
GitHub Actions (CI/CD pipelines)
    │
    ├── ci.yml          ← runs on every Pull Request
    │     lint → test → build → security scan → comment on PR
    │
    ├── cd-staging.yml  ← runs on every merge to main
    │     build image → push to ECR → terraform apply → smoke test
    │
    ├── cd-production.yml ← you trigger this manually
    │     security gate → human approval → terraform apply → smoke test
    │
    └── drift-detect.yml  ← runs every night at 2am UTC
          terraform plan → alert if infrastructure changed unexpectedly

AWS Infrastructure (created by Terraform)
    │
    ├── VPC (private network)
    ├── ALB (load balancer) ← users hit this URL
    ├── ECS Fargate (runs your container)
    ├── ECR (stores Docker images)
    ├── RDS Aurora (database)
    ├── S3 (storage)
    └── CloudWatch (logs + monitoring)
```

---

## 3. Repository Structure Explained

```
terraform-aws-infra/
│
├── CLAUDE.md                    ← Instructions for the Claude AI agent
│
├── .claude/                     ← Claude Code configuration
│   ├── CLAUDE.md                ← Same instructions (read by Claude Code CLI)
│   └── skills/                  ← Automated tasks Claude can perform
│       ├── deploy-ecs/          ← How to deploy to ECS
│       ├── scan-security/       ← How to run security scans
│       ├── test-integration/    ← How to run tests
│       ├── rotate-secrets/      ← How to rotate AWS secrets
│       └── drift-detection/     ← How to check for infrastructure drift
│
├── .github/
│   └── workflows/               ← GitHub Actions pipelines (run automatically)
│       ├── ci.yml               ← Runs on every Pull Request
│       ├── cd-staging.yml       ← Deploys to staging on merge to main
│       ├── cd-production.yml    ← Deploys to production (requires approval)
│       └── drift-detect.yml     ← Nightly infrastructure health check
│
├── infrastructure/
│   ├── terraform/               ← Infrastructure as Code (defines all AWS resources)
│   │   ├── main.tf              ← Wires all modules together
│   │   ├── variables.tf         ← Input parameters
│   │   ├── outputs.tf           ← Values exported after apply (URLs, ARNs, etc.)
│   │   ├── backend.tf           ← Where Terraform saves its state (S3)
│   │   ├── providers.tf         ← Configures AWS provider
│   │   ├── modules/
│   │   │   ├── ecs-service/     ← ECS cluster, tasks, ALB, auto-scaling
│   │   │   ├── ecr-repo/        ← Docker image registry
│   │   │   ├── monitoring/      ← CloudWatch dashboards and alarms
│   │   │   ├── vpc/             ← Network (subnets, NAT, routing)
│   │   │   ├── rds/             ← Aurora PostgreSQL database
│   │   │   └── s3/              ← Object storage bucket
│   │   └── environments/        ← Per-environment configuration
│   │       ├── dev.tfvars       ← Development settings (small/cheap)
│   │       ├── staging.tfvars   ← Staging settings (mirrors prod)
│   │       └── prod.tfvars      ← Production settings (HA, larger instances)
│   └── ansible/                 ← Host configuration and hardening
│
├── src/                         ← Your application code
│   ├── app/
│   │   ├── main.py              ← FastAPI web application
│   │   ├── requirements.txt     ← Python dependencies
│   │   ├── requirements-dev.txt ← Dev/test dependencies
│   │   └── tests/
│   │       ├── unit/            ← Fast tests (no network/database)
│   │       └── integration/     ← Tests against a live environment
│   ├── Dockerfile               ← How to build the container image
│   ├── .dockerignore            ← Files excluded from Docker build
│   └── entrypoint.sh            ← Container startup script
│
├── scripts/
│   ├── bootstrap.sh             ← One-time AWS setup (run once, ever)
│   ├── validate-iac.sh          ← Security check on Terraform code
│   ├── auto-rollback.sh         ← Reverts ECS to previous version
│   └── smoke-test.sh            ← Quick post-deploy health check
│
├── docs/
│   ├── ARCHITECTURE.md          ← Deep-dive architecture explanation
│   ├── RUNBOOK.md               ← What to do when things break
│   └── COMPLIANCE.md            ← Security compliance mapping
│
├── Makefile                     ← Shortcuts for common commands
├── pyproject.toml               ← Python project config (linting, testing)
├── .pre-commit-config.yaml      ← Auto-checks before every git commit
└── .gitignore                   ← Files Git should not track
```

---

## 4. Prerequisites — Install Everything First

You need these tools on your machine before doing anything else.

### 4.1 AWS CLI

The command-line tool to talk to AWS.

```bash
# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# macOS (with Homebrew)
brew install awscli

# Verify it works
aws --version
# Expected output: aws-cli/2.x.x ...
```

### 4.2 Terraform

Deploys and manages AWS infrastructure from code.

```bash
# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify
terraform --version
# Expected: Terraform v1.6.x or newer
```

### 4.3 Docker

Builds and runs containers locally.

```bash
# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install docker.io
sudo usermod -aG docker $USER   # lets you run docker without sudo
newgrp docker                   # apply group change without logout

# macOS
# Download Docker Desktop from https://www.docker.com/products/docker-desktop/

# Verify
docker --version
# Expected: Docker version 24.x.x or newer
```

### 4.4 Python 3.12

The language the app is written in.

```bash
# Linux (Ubuntu/Debian)
sudo apt install python3.12 python3.12-venv python3-pip

# macOS
brew install python@3.12

# Verify
python3 --version
# Expected: Python 3.12.x
```

### 4.5 Git

Version control — you probably already have this.

```bash
# Linux
sudo apt install git

# macOS
brew install git

# Verify
git --version
```

### 4.6 GitHub CLI (gh)

Interact with GitHub from the terminal (needed to trigger prod deploys).

```bash
# Linux (Ubuntu/Debian)
sudo apt install gh

# macOS
brew install gh

# Login to GitHub
gh auth login
# Follow the prompts: choose GitHub.com → HTTPS → authenticate via browser

# Verify
gh auth status
```

### 4.7 make

Runs shortcuts defined in the Makefile.

```bash
# Linux — usually pre-installed, if not:
sudo apt install make

# macOS — comes with Xcode command line tools:
xcode-select --install

# Verify
make --version
```

### 4.8 Security scanning tools (optional for local use)

These run automatically in CI, but you can also run them locally.

```bash
# Trivy — container vulnerability scanner
# Linux
sudo apt install wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt update && sudo apt install trivy

# macOS
brew install trivy

# tfsec — Terraform security scanner
# Linux/macOS
brew install tfsec
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Checkov — IaC policy scanner
pip install checkov
```

---

## 5. AWS Account Setup

### 5.1 Create an AWS account

If you don't have one: go to [https://aws.amazon.com](https://aws.amazon.com) and click **Create an AWS Account**.

> **Cost warning:** This project uses services that cost money. Running dev/staging for a day costs approximately $2-5 USD. Always run `make destroy` when you're done experimenting.

### 5.2 Create an IAM user with programmatic access

1. Log into the [AWS Console](https://console.aws.amazon.com)
2. Go to **IAM** → **Users** → **Create user**
3. Username: `terraform-deployer`
4. Check **Provide user access to the AWS Management Console** → No
5. Click **Next** → **Attach policies directly**
6. Attach: `AdministratorAccess` (for learning; restrict in real projects)
7. Click **Create user**
8. Click on the user → **Security credentials** → **Create access key**
9. Choose **Command Line Interface (CLI)**
10. Copy the **Access key ID** and **Secret access key** — you only see them once

### 5.3 Configure AWS CLI with your credentials

```bash
aws configure
```

It will ask for:
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE        ← paste yours
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY  ← paste yours
Default region name [None]: us-east-1
Default output format [None]: json
```

Verify it works:

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAIOSFODNN7EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-deployer"
}
```

Note your **Account** number — you'll need it in step 6.

---

## 6. GitHub Repository Setup

### 6.1 Fork or create the repository

If you cloned this project, push it to your own GitHub account:

```bash
# Create a new repo on GitHub (replace YOUR_USERNAME)
gh repo create YOUR_USERNAME/cicd-python-aws-ecs --public --push --source=.
```

Or if you already have a remote:

```bash
git remote -v                          # see current remotes
git remote set-url origin https://github.com/YOUR_USERNAME/cicd-python-aws-ecs.git
git push -u origin main
```

### 6.2 Set GitHub Actions secrets and variables

GitHub Actions needs to know your AWS account ID and other config. Go to:
**GitHub → your repo → Settings → Secrets and variables → Actions**

Click **New repository secret** and add each one:

| Name | Value | Where to find it |
|------|-------|-----------------|
| `AWS_ACCOUNT_ID` | `123456789012` | `aws sts get-caller-identity` output |

Click **New repository variable** (not secret — these aren't sensitive) and add:

| Name | Example value | Description |
|------|--------------|-------------|
| `STAGING_URL` | `http://my-alb-123.us-east-1.elb.amazonaws.com` | Fill in after first deploy |
| `PROD_URL` | `http://my-alb-456.us-east-1.elb.amazonaws.com` | Fill in after first deploy |
| `ECR_REGISTRY` | `123456789012.dkr.ecr.us-east-1.amazonaws.com` | Your account ID + region |

### 6.3 Set up GitHub OIDC for AWS (passwordless auth)

This lets GitHub Actions authenticate to AWS without storing long-lived keys.

```bash
# Step 1: Create the OIDC identity provider in AWS
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Step 2: Create the IAM role GitHub Actions will assume
# Replace YOUR_GITHUB_USERNAME and YOUR_REPO_NAME below
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
EOF

# Replace YOUR_ACCOUNT_ID in the file
sed -i 's/YOUR_ACCOUNT_ID/'"$(aws sts get-caller-identity --query Account --output text)"'/g' /tmp/trust-policy.json

aws iam create-role \
  --role-name GitHubActions-Deploy \
  --assume-role-policy-document file:///tmp/trust-policy.json

aws iam attach-role-policy \
  --role-name GitHubActions-Deploy \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo "Role ARN:"
aws iam get-role --role-name GitHubActions-Deploy --query Role.Arn --output text
```

> Add the role ARN to your GitHub Actions secrets as `ROLE_ARN` if you want to reference it explicitly, or update the workflows to use your account ID directly.

---

## 7. First-Time Bootstrap

This step creates the AWS resources Terraform needs to store its own state (S3 bucket + DynamoDB table). **Run this once, ever.**

```bash
# Clone the repo if you haven't already
git clone https://github.com/YOUR_USERNAME/cicd-python-aws-ecs.git
cd cicd-python-aws-ecs

# Set your project name (used to name AWS resources)
export PROJECT_NAME=cicd-python-ecs
export AWS_REGION=us-east-1

# Run the bootstrap script
make bootstrap
```

What this does:
1. Creates an S3 bucket (`tf-state-cicd-python-aws-ecs`) to store Terraform state files
2. Creates a DynamoDB table (`tf-state-lock`) to prevent simultaneous deployments
3. Initializes Terraform and creates 3 workspaces: `dev`, `staging`, `prod`

Expected output:
```
==> Creating S3 backend bucket: tf-state-cicd-python-aws-ecs
==> Creating DynamoDB lock table: tf-state-lock
==> Initializing Terraform workspaces
==> Bootstrap complete
  State bucket : tf-state-cicd-python-aws-ecs
  Lock table   : tf-state-lock
```

---

## 8. Running the App Locally

Before deploying anywhere, verify the app works on your machine.

### 8.1 Set up a Python virtual environment

```bash
# From the repo root
python3 -m venv .venv
source .venv/bin/activate       # Linux/macOS
# Windows: .venv\Scripts\activate

# Install dependencies
pip install -r src/app/requirements.txt
pip install -r src/app/requirements-dev.txt
```

### 8.2 Run the app

```bash
cd src/app
uvicorn app.main:app --reload --port 8000
```

Open your browser at [http://localhost:8000](http://localhost:8000)

You should see:
```json
{"message": "cicd-python-ecs API", "environment": "dev"}
```

Health check: [http://localhost:8000/health](http://localhost:8000/health)
```json
{"status": "healthy", "environment": "dev", "timestamp": "2026-04-01T12:00:00"}
```

Press `Ctrl+C` to stop.

### 8.3 Run the tests

```bash
# From repo root
make test
```

This runs all unit tests and checks that code coverage is at least 90%.

Expected output:
```
tests/unit/test_health.py ...                    [ 100%]

---------- coverage: platform linux, python 3.12 ----------
Name              Stmts   Miss  Cover
app/main.py          18      0   100%
TOTAL                18      0   100%

3 passed in 0.45s
```

### 8.4 Check code style

```bash
make lint
```

If there are style issues, auto-fix them:

```bash
make format
```

### 8.5 Build and run with Docker

```bash
# Build the image
make build

# Run it
docker run -p 8000:8000 app:sha-$(git rev-parse --short HEAD)

# Test it
curl http://localhost:8000/health
```

---

## 9. Deploying to Staging

Staging is deployed **automatically** every time you merge code to the `main` branch. But you can also trigger it manually.

### 9.1 Automatic deploy (recommended)

```bash
# Create a branch, make a change, open a PR
git checkout -b my-feature
echo "# change" >> src/app/main.py
git add src/app/main.py
git commit -m "my first change"
git push origin my-feature

# Open a pull request
gh pr create --title "My first change" --body "Testing the pipeline"
```

GitHub Actions will automatically run the CI pipeline. Watch it at:
**GitHub → your repo → Actions**

When you see all checks pass, merge the PR:

```bash
gh pr merge --merge
```

The `cd-staging.yml` workflow kicks off immediately and deploys to staging.

### 9.2 Manual deploy to staging

```bash
# From repo root, after make bootstrap
make tf-plan ENV=staging
# Review the plan — it shows what AWS resources will be created

make tf-apply ENV=staging
```

### 9.3 Get the staging URL

After `terraform apply` completes:

```bash
cd infrastructure/terraform
terraform workspace select staging
terraform output alb_dns_name
```

Copy that URL and test it:

```bash
curl http://<alb_dns_name>/health
```

Update your GitHub variable `STAGING_URL` with this value.

---

## 10. Deploying to Production

Production requires a **manual approval step** to prevent accidents.

### 10.1 Trigger the production workflow

```bash
# Replace sha-abc1234 with the actual image tag from a successful staging deploy
gh workflow run cd-production.yml \
  --repo YOUR_USERNAME/cicd-python-aws-ecs \
  -f image_tag=sha-$(git rev-parse --short HEAD)
```

### 10.2 Approve in GitHub

1. Go to **GitHub → your repo → Actions**
2. Click the running `CD — Production` workflow
3. You'll see a yellow box saying **"Waiting for review"**
4. Click **Review deployments** → check the box → **Approve and deploy**

The workflow will then:
1. Run all security gates (Trivy, tfsec, checkov)
2. Apply Terraform to prod
3. Wait for ECS to stabilize
4. Run smoke tests

### 10.3 Manual prod deploy (emergency only)

```bash
make tf-plan ENV=prod
make tf-apply ENV=prod
```

### 10.4 Get the production URL

```bash
cd infrastructure/terraform
terraform workspace select prod
terraform output alb_dns_name
```

---

## 11. Understanding the CI/CD Pipelines

### ci.yml — runs on every Pull Request

```
Step 1: lint
  → ruff (catches bugs and style issues in Python)
  → black (formats code consistently)
  → isort (sorts import statements)

Step 2: test
  → pytest (runs all unit tests)
  → coverage gate: fails if < 90% of code is tested

Step 3: build
  → docker build (creates the container image)

Step 4: scan
  → Trivy (scans image for known vulnerabilities — blocks on CRITICAL)
  → tfsec (scans Terraform for security misconfigs — blocks on HIGH)
  → checkov (checks compliance — blocks if score < 95%)
  → Bandit (scans Python code for security issues)

Step 5: comment results on the PR
```

### cd-staging.yml — runs on merge to main

```
1. Build Docker image → tag as sha-<commit_hash>
2. Push to ECR (Amazon's private Docker registry)
3. terraform apply -var="image_tag=sha-<hash>" -auto-approve
4. Wait for ECS to finish deploying (up to 5 minutes)
5. Run smoke-test.sh (checks /health returns 200)
6. If anything fails: auto-rollback to previous image
```

### cd-production.yml — you trigger this manually

```
1. Security gate (Trivy + tfsec + checkov — must all pass)
2. Human approval required in GitHub UI
3. terraform apply for prod environment
4. Wait for ECS stabilization
5. Extended smoke test (10 minute timeout)
6. If anything fails: auto-rollback
```

### drift-detect.yml — runs every night at 2am UTC

```
For each environment (dev, staging, prod):
  → terraform plan -detailed-exitcode
  → If plan shows changes (exit code 2): something drifted!
    → Creates a GitHub Issue with the diff
    → Emits a CloudWatch metric (DriftDetected)

Also:
  → Rotates non-critical secrets (API keys, tokens)
  → Deletes ECR images older than 30 days
```

---

## 12. Makefile Cheat Sheet

Run any of these from the repository root.

```bash
# ── Local Development ────────────────────────────────────────────
make lint                    # Check code style (ruff, black, isort)
make format                  # Auto-fix code style issues
make test                    # Run unit tests + coverage check
make build                   # Build Docker image locally
make scan                    # Run all security scans locally

# ── Terraform ────────────────────────────────────────────────────
make tf-init                 # Initialize Terraform (run after git clone)
make tf-plan ENV=staging     # Show what changes Terraform will make
make tf-plan ENV=prod        # Same, for prod
make tf-apply ENV=staging    # Actually apply the changes to staging
make tf-apply ENV=prod       # Apply to prod (careful!)
make tf-drift ENV=prod       # Check for infrastructure drift

# ── Deployment ───────────────────────────────────────────────────
make deploy-staging          # Full pipeline: build → scan → deploy staging
make deploy-prod             # Full pipeline: build → scan → deploy prod

# ── Emergency ────────────────────────────────────────────────────
make rollback ENV=staging    # Revert ECS to previous Docker image (staging)
make rollback ENV=prod       # Revert ECS to previous Docker image (prod)

# ── Setup ────────────────────────────────────────────────────────
make bootstrap               # One-time AWS setup (S3 state, DynamoDB lock)
make validate                # Run tfsec + checkov on Terraform code
```

**Pass variables to make commands like this:**

```bash
make tf-plan ENV=prod IMAGE_TAG=sha-abc1234
make deploy-staging STAGING_URL=http://my-alb.amazonaws.com
```

---

## 13. Claude Code Skills

This project ships with 5 autonomous skills that Claude Code can invoke. Think of them as pre-built automation playbooks.

### What are skills?

Skills are defined in `.claude/skills/*/SKILL.md`. They tell the Claude Code agent exactly what steps to follow, what inputs to accept, and what JSON to return.

### How to invoke them

In the terminal with Claude Code running:

```
@skill deploy-ecs --env=staging --image=app:sha-abc123
```

Or describe what you want in plain English:

```
Deploy the latest image to staging
```

### Available skills

| Skill | What it does |
|-------|-------------|
| `deploy-ecs` | Zero-downtime deploy to ECS with auto-rollback on failure |
| `scan-security` | Full security scan: SCA + SAST + container + IaC |
| `test-integration` | Run pytest suite + enforce 90% coverage |
| `rotate-secrets` | Rotate AWS Secrets Manager non-critical secrets |
| `drift-detection` | Run `terraform plan` and alert if infra drifted |

### Example invocations

```bash
# Deploy staging with a specific image tag
@skill deploy-ecs --env=staging --image=app:sha-abc123 --force=false

# Check if prod infra has drifted from Terraform state
@skill drift-detection --env=prod --alert=true

# Run security scan on the codebase
@skill scan-security --target=src/ --level=high

# Rotate secrets in staging
@skill rotate-secrets --env=staging --dry_run=true
```

---

## 14. Troubleshooting

### "terraform: command not found"

Terraform is not installed or not in your PATH. Re-run the install steps in [section 4.2](#42-terraform).

### "aws: Unable to locate credentials"

Your AWS credentials aren't configured. Run `aws configure` and enter your access key and secret (see [section 5.3](#53-configure-aws-cli-with-your-credentials)).

### "Error: No valid credential sources found"

```bash
# Verify credentials are set
aws sts get-caller-identity

# If that fails, re-configure
aws configure
```

### "docker: permission denied"

You need to add yourself to the docker group:

```bash
sudo usermod -aG docker $USER
newgrp docker    # or log out and back in
```

### GitHub Actions fails with "credentials error"

The OIDC role trust policy probably has the wrong repo name. Check:

```bash
aws iam get-role --role-name GitHubActions-Deploy \
  --query Role.AssumeRolePolicyDocument
```

Make sure the `sub` condition matches `repo:YOUR_USERNAME/YOUR_REPO_NAME:*`.

### "terraform init" fails with "bucket does not exist"

You haven't run bootstrap yet:

```bash
make bootstrap
```

### ECS tasks keep crashing (deployment stuck)

Check the container logs:

```bash
# Get the cluster name
aws ecs list-clusters

# Get the service name
aws ecs list-services --cluster cicd-python-ecs-staging

# View logs
aws logs tail /ecs/cicd-python-ecs-staging --follow
```

### Smoke test times out after deployment

The app might be starting slowly. Increase the timeout:

```bash
./scripts/smoke-test.sh --env=staging \
  --endpoint=http://<ALB_DNS>/health \
  --timeout=600
```

Or check ECS task health:

```bash
aws ecs describe-services \
  --cluster cicd-python-ecs-staging \
  --services cicd-python-ecs-staging \
  --query "services[0].{desired:desiredCount, running:runningCount, pending:pendingCount}"
```

### "checkov" blocks the pipeline with too many findings

Check which checks are failing:

```bash
checkov -d infrastructure/terraform/ --output json | \
  jq '.results.failed_checks[] | .check_id + ": " + .check_result.result'
```

To skip a specific check (add a comment in the Terraform file):

```hcl
resource "aws_s3_bucket" "example" {
  #checkov:skip=CKV_AWS_18:Access logging not needed for this bucket
}
```

### How to rollback manually

```bash
# ECS rollback (reverts to previous task definition)
make rollback ENV=staging

# Or manually via Terraform
make tf-apply ENV=staging IMAGE_TAG=sha-<previous-commit-hash>
```

---

## 15. Teardown — Delete Everything

When you're done experimenting, delete all AWS resources to avoid charges.

```bash
# Destroy staging
cd infrastructure/terraform
terraform workspace select staging
terraform destroy -var-file=environments/staging.tfvars -auto-approve

# Destroy prod
terraform workspace select prod
terraform destroy -var-file=environments/prod.tfvars -auto-approve

# Destroy dev
terraform workspace select dev
terraform destroy -var-file=environments/dev.tfvars -auto-approve

# Delete the S3 state bucket (empty it first)
aws s3 rm s3://tf-state-cicd-python-aws-ecs --recursive
aws s3api delete-bucket --bucket tf-state-cicd-python-aws-ecs

# Delete the DynamoDB lock table
aws dynamodb delete-table --table-name tf-state-lock

# Delete the ECR repository (this removes all images)
aws ecr delete-repository \
  --repository-name cicd-python-ecs \
  --force
```

> After running `terraform destroy`, always verify in the AWS Console that no resources remain, especially EC2 instances, NAT Gateways, and Load Balancers (these cost the most).

---

## Further Reading

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Deep-dive into the AWS architecture
- [docs/RUNBOOK.md](docs/RUNBOOK.md) — What to do when things break
- [docs/COMPLIANCE.md](docs/COMPLIANCE.md) — NIST 800-53 security control mapping
- [CLAUDE.md](CLAUDE.md) — Claude Code agent automation instructions
- [AWS ECS Fargate documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
