# CLAUDE.md — Autonomous CI/CD Agent Instructions

## Mission
Automate all CI/CD, infrastructure, and operational tasks for this Python/AWS/ECS project with **zero human intervention**, while maintaining:
- STIG/NIST 800-53 compliance
- IAT Level III security boundaries
- GitOps principles (immutable artifacts, declarative state)
- Full auditability (CloudTrail + CloudWatch Logs `/claude/agent`)

## Repository Layout

```
infrastructure/terraform/   — Terraform for ECS, ECR, VPC, RDS, S3, monitoring
infrastructure/ansible/     — Ansible playbooks for host hardening
src/                        — Python application (Dockerfile, tests)
scripts/                    — bootstrap, IaC validation, auto-rollback
.claude/skills/             — Autonomous skill definitions
.github/workflows/          — GitHub Actions CI/CD pipelines
docs/                       — Architecture, runbook, compliance mapping
```

## Hard Constraints (NEVER bypass)

- Never deploy to `prod` without ALL of these passing:
  - `tfsec --severity HIGH` = 0 findings
  - `checkov` compliance score >= 95%
  - `pytest --cov=app --cov-fail-under=90`
  - Trivy scan: 0 CRITICAL vulnerabilities
- Never modify Terraform state manually — always use `terraform apply` via CI
- Never hardcode secrets — use AWS Secrets Manager + IAM roles only
- Never skip pre-commit hooks (`--no-verify`)
- Never push directly to `main` — all changes via PR

## Autonomous Behaviors

### On Pull Request
1. Run `make lint`
2. Run `make test` (pytest + coverage gate)
3. Build Docker image (no push)
4. Run `make scan` (Trivy + tfsec + checkov)
5. Comment structured results on PR

### On merge to `main`
1. Build & push Docker image to ECR (tag: `sha-<short>`)
2. Update `image_tag` in `environments/staging.tfvars`
3. `terraform apply -var-file=environments/staging.tfvars -auto-approve`
4. Run `scripts/smoke-test.sh --env=staging`
5. If green: auto-promote to prod (or await `approved` label)

### Nightly (02:00 UTC)
- `terraform plan -detailed-exitcode` on all environments → alert on drift
- Rotate non-critical secrets via `@skill rotate-secrets`
- Archive ECR images older than 30 days

## Skill Invocation Protocol

```
@skill deploy-ecs --env=staging --image=app:abc123 --force=false
@skill scan-security --target=src/ --level=high
@skill test-integration --env=staging --timeout=300
@skill rotate-secrets --env=prod --secret-prefix=/app/
@skill drift-detection --env=prod --alert=true
```

Skills return machine-readable JSON for pipeline integration.

## Self-Healing Rules

| Condition | Automated Response |
|-----------|-------------------|
| ECS task fails > 3x | Auto-rollback to previous image tag |
| `terraform apply` fails | Run `terraform plan`, post diff to PR + alert |
| Test coverage drops below 90% | Block merge + suggest missing test cases |
| Drift detected | Create PR with corrective `terraform apply` |
| CPU alarm fires | Scale out ECS tasks, alert #devops-alerts |

## Observability

- Agent action log: CloudWatch `/claude/agent`
- Metrics namespace: `Claude/Agent` (AgentActions, AutomationFailures, DriftDetected)
- Dashboard: `{project}-{environment}` in CloudWatch
- Alerts: SNS → Slack + PagerDuty on failure or policy violation
