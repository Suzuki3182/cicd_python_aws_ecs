# Skill: rotate-secrets

## Purpose
Autonomously rotate AWS Secrets Manager secrets for non-critical credentials (API keys, service tokens). Excludes database master passwords (rotated by RDS natively).

## Inputs
```json
{
  "environment": "dev|staging|prod",
  "secret_prefix": "/app/",
  "dry_run": false,
  "notify": true
}
```

## Execution Steps

1. **List secrets** matching `$secret_prefix` in `$environment`
   ```bash
   aws secretsmanager list-secrets \
     --filter Key=name,Values=$secret_prefix \
     --query "SecretList[*].{Name:Name,LastRotated:LastRotatedDate}" \
     --output json
   ```

2. **Filter secrets** that are eligible for rotation:
   - Not excluded (e.g. `db-master-password`, `rds/`)
   - Last rotated > 30 days ago (or never rotated)

3. **For each eligible secret** (if `dry_run=false`):
   ```bash
   aws secretsmanager rotate-secret \
     --secret-id $secret_name \
     --rotation-rules AutomaticallyAfterDays=30
   ```

4. **Verify rotation** — poll until `RotationEnabled=true` and `LastRotatedDate` updated

5. **Force ECS task refresh** to pick up new secret values:
   ```bash
   aws ecs update-service \
     --cluster $cluster_name \
     --service $service_name \
     --force-new-deployment
   ```

6. **Post rotation summary** to CloudWatch `/claude/agent`

## Output (JSON)
```json
{
  "status": "success|failed",
  "environment": "prod",
  "secrets_evaluated": 8,
  "secrets_rotated": 3,
  "secrets_skipped": 5,
  "dry_run": false,
  "rotated": [
    { "name": "/app/prod/api-key", "rotated_at": "2026-04-01T02:00:00Z" }
  ],
  "errors": []
}
```

## Guardrails
- Never rotates `rds/` or `db-master` prefixed secrets (managed by RDS)
- `dry_run=true` by default in non-nightly contexts — requires explicit override
- Rotation logged to CloudTrail + CloudWatch `/claude/agent`
- On rotation failure: alert `#devops-alerts`, do NOT proceed to next secret
