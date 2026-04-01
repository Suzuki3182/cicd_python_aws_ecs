# Runbook — Human Fallback Procedures

## Manual ECS Rollback

```bash
# 1. Find the previous task definition revision
aws ecs describe-services \
  --cluster cicd-python-ecs-prod \
  --services cicd-python-ecs-prod \
  --query "services[0].taskDefinition"

# 2. Update the service to use previous revision
aws ecs update-service \
  --cluster cicd-python-ecs-prod \
  --service cicd-python-ecs-prod \
  --task-definition cicd-python-ecs-prod:<PREV_REVISION>

# 3. Or use the auto-rollback script
./scripts/auto-rollback.sh --env=prod --cluster=cicd-python-ecs-prod
```

## Emergency Terraform Apply

```bash
cd infrastructure/terraform
terraform init
terraform workspace select prod
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

## Database Emergency Access

```bash
# Get credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id /cicd-python-ecs/prod/db-master \
  --query SecretString --output text | jq .

# Connect via ECS Exec (no bastion required)
aws ecs execute-command \
  --cluster cicd-python-ecs-prod \
  --task <TASK_ID> \
  --container app \
  --command "/bin/bash" \
  --interactive
```

## Scale ECS Service Manually

```bash
aws ecs update-service \
  --cluster cicd-python-ecs-prod \
  --service cicd-python-ecs-prod \
  --desired-count 5
```

## View Application Logs

```bash
# Last 100 lines from all tasks
aws logs tail /ecs/cicd-python-ecs-prod --follow

# Agent action log
aws logs tail /claude/agent --follow
```

## Drift Recovery

```bash
cd infrastructure/terraform
terraform workspace select prod
terraform plan -var-file=environments/prod.tfvars -detailed-exitcode
# If exit code 2 (drift detected):
terraform apply -var-file=environments/prod.tfvars
```
