# GitHub Actions OIDC + Secrets Setup Guide

This repository uses AWS OIDC federation for GitHub Actions role assumption.

## 1) Prerequisites

- AWS CLI configured with IAM permissions to manage IAM OIDC providers/roles
- GitHub CLI authenticated (`gh auth login`)
- Repository access to `<OWNER>/<REPO>`

## 2) Create or update GitHub OIDC provider

```bash
cd <repo-root>
bash scripts/aws-setup/setup-oidc-provider.sh
```

## 3) Create or update IAM roles for workflows

```bash
bash scripts/aws-setup/setup-iam-roles.sh --repo <OWNER>/<REPO>
```

Roles created/updated:

- `GitHubActions-Deploy`
- `GitHubActions-ReadOnly`
- `GitHubActions-SecretsRotation`

## 4) Configure required GitHub repository secrets

```bash
export AWS_ACCOUNT_ID=123456789012
export STAGING_URL=https://staging.example.com
export PROD_URL=https://prod.example.com
export ECR_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com

bash scripts/github-setup/setup-secrets.sh --repo <OWNER>/<REPO>
```

Required secrets:

- `AWS_ACCOUNT_ID`
- `STAGING_URL`
- `PROD_URL`
- `ECR_REGISTRY`

## 5) Verify OIDC trust + role configuration

```bash
bash scripts/aws-setup/verify-oidc.sh --repo <OWNER>/<REPO>
```

If verification passes, workflows can assume AWS roles using:

`arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActions-*`
