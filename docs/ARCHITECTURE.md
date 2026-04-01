# Architecture

## Overview

Python microservice deployed on **AWS ECS Fargate** with automated GitOps CI/CD via GitHub Actions and Terraform.

```
Internet
    │
    ▼
[ALB] (public subnets)
    │
    ▼
[ECS Fargate Tasks] (private subnets)
    │           │
    ▼           ▼
[Aurora RDS]  [S3 Artifacts]
(private)
```

## Components

| Component | Service | Notes |
|-----------|---------|-------|
| Compute | ECS Fargate | No EC2 management, scales to zero |
| Container Registry | Amazon ECR | Image scanning on push, KMS encrypted |
| Database | Aurora PostgreSQL | Multi-AZ, auto-scaling, encrypted |
| Object Storage | S3 | Versioning, KMS, lifecycle policies |
| Load Balancer | ALB | Health checks, blue/green ready |
| Secrets | Secrets Manager | Auto-rotation, injected at runtime |
| Monitoring | CloudWatch | Container Insights, custom dashboards |
| IaC | Terraform | Remote S3 state + DynamoDB locking |

## CI/CD Pipeline

```
PR opened
  └─> ci.yml: lint → unit tests → docker build → security scan
        └─> PR comment with results

Merge to main
  └─> cd-staging.yml: build → ECR push → terraform apply → smoke test
        └─> If green: cd-production.yml (manual approval) → prod deploy

Nightly (02:00 UTC)
  └─> drift-detect.yml: terraform plan all envs → alert on drift
                       → rotate secrets → archive old ECR images
```

## Security Architecture

- **Network**: VPC with public/private subnets, NAT gateway, no public IPs on tasks
- **Auth**: GitHub OIDC → IAM roles (no long-lived credentials)
- **Secrets**: AWS Secrets Manager, injected via ECS task definition secrets
- **Encryption**: KMS for ECR, RDS, S3; TLS for all traffic
- **Compliance**: NIST 800-53 controls mapped in [COMPLIANCE.md](COMPLIANCE.md)
- **Scanning**: Trivy (container), tfsec + checkov (IaC), Bandit (SAST), pip-audit (SCA)

## Terraform Workspaces

```
infrastructure/terraform/
├── environments/
│   ├── dev.tfvars      — single NAT, minimal sizing
│   ├── staging.tfvars  — mirrors prod topology
│   └── prod.tfvars     — multi-AZ, full HA
└── modules/
    ├── vpc/            — network foundation
    ├── ecs-service/    — Fargate cluster + service + ALB
    ├── ecr-repo/       — container registry
    ├── rds/            — Aurora PostgreSQL
    ├── s3/             — artifact + app storage
    └── monitoring/     — CloudWatch dashboards + alarms
```
