# Compliance — NIST 800-53 Control Mapping

## Audit Trail (AU)

| Control | Implementation |
|---------|---------------|
| AU-2 | CloudTrail enabled, all API calls logged |
| AU-3 | CloudWatch Logs with structured JSON fields |
| AU-9 | Log groups encrypted with KMS; restricted IAM |
| AU-12 | auditd on ECS hosts (harden-hosts.yml) |

## Access Control (AC)

| Control | Implementation |
|---------|---------------|
| AC-2 | IAM roles, no shared credentials |
| AC-3 | Least-privilege task execution + task roles |
| AC-6 | ECS tasks run as non-root (UID 1001) |
| AC-17 | SSH disabled on Fargate; ECS Exec via SSM |

## Identification & Authentication (IA)

| Control | Implementation |
|---------|---------------|
| IA-2 | GitHub OIDC → IAM role assumption (no passwords) |
| IA-3 | IMDSv2 enforced on all EC2 instances |
| IA-5 | Secrets Manager auto-rotation (30-day cycle) |

## System and Communications Protection (SC)

| Control | Implementation |
|---------|---------------|
| SC-8 | TLS enforced for all traffic (ALB, RDS, S3) |
| SC-12 | KMS for ECS secrets, RDS, S3, ECR |
| SC-28 | Encryption at rest on all storage services |

## Configuration Management (CM)

| Control | Implementation |
|---------|---------------|
| CM-2 | Terraform declarative state (immutable IaC) |
| CM-6 | STIG hardening via Ansible harden-hosts.yml |
| CM-7 | Minimal container image (python:3.12-slim) |
| CM-8 | ECR image scanning on every push |

## System and Information Integrity (SI)

| Control | Implementation |
|---------|---------------|
| SI-2 | Automated dependency updates (pip-audit, Trivy) |
| SI-3 | Container image scanning (Trivy) before every deploy |
| SI-4 | CloudWatch Container Insights + custom metrics |
| SI-7 | Deployment circuit breaker + auto-rollback |
