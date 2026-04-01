# Skill: deploy-ecs

## Purpose
Autonomously deploy a new container image to Amazon ECS (Fargate) with zero-downtime rolling update, health validation, and auto-rollback on failure.

## Inputs
```json
{
  "environment": "staging|prod",
  "image_tag": "sha-abc123",
  "service_name": "app",
  "force": false,
  "skip_tests": false
}
```

## Execution Steps

1. **Validate inputs** against `infrastructure/terraform/environments/*.tfvars`
2. **Pre-flight checks**
   - Confirm `image_tag` exists in ECR
   - Verify `tfsec` + `checkov` last run < 24h (or re-run)
   - If `environment=prod` and `force=false`: require `approved` label on PR
3. **Run smoke tests** (unless `skip_tests=true`)
   ```bash
   ./scripts/smoke-test.sh --env=$environment --timeout=120
   ```
4. **Apply Terraform**
   ```bash
   cd infrastructure/terraform
   terraform workspace select $environment
   terraform apply -var-file=environments/$environment.tfvars \
                   -var="image_tag=$image_tag" \
                   -auto-approve
   ```
5. **Wait for ECS stabilization** — poll until `runningCount == desiredCount` (timeout: 5 min)
6. **Post-deploy validation**
   - HTTP 200 on `/health` endpoint
   - CloudWatch alarm `ecs-cpu-high` in OK state
   - No ERROR entries in `/ecs/{service}` log group (last 2 min)
7. **On failure**
   - Auto-rollback: `terraform apply -var="image_tag=$previous_tag" -auto-approve`
   - Post incident summary to `#devops-alerts`
   - Log to CloudWatch `/claude/agent` with `status=failed`

## Output (JSON)
```json
{
  "status": "success|failed",
  "environment": "staging",
  "image_tag": "sha-abc123",
  "previous_tag": "sha-prev456",
  "deployment_id": "ecs-svc/xxxxxxxx",
  "rollback_available": true,
  "health_check": { "status": 200, "latency_ms": 42 },
  "logs_url": "https://console.aws.amazon.com/cloudwatch/...",
  "duration_seconds": 87
}
```

## Guardrails
- Requires IAM role `GitHubActions-Deploy` (OIDC — no long-lived keys)
- `prod` deployments blocked if `force=false` and no approval label
- Enforces `--wait` / polling on `aws ecs wait services-stable`
- All actions logged to `/claude/agent` with structured JSON
