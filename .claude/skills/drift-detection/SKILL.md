# Skill: drift-detection

## Purpose
Detect infrastructure drift between live AWS state and Terraform declarations. Alert on differences and optionally create a corrective PR.

## Inputs
```json
{
  "environment": "dev|staging|prod",
  "auto_pr": false,
  "alert": true,
  "backend_bucket": "tf-state-cicd-python-aws-ecs"
}
```

## Execution Steps

1. **Initialize Terraform with remote backend**
   ```bash
   cd infrastructure/terraform
   terraform init -backend-config="bucket=$backend_bucket" -reconfigure
   terraform workspace select $environment
   ```

2. **Run drift detection plan**
   ```bash
   terraform plan \
     -var-file=environments/$environment.tfvars \
     -detailed-exitcode \
     -out=drift-plan.tfplan \
     -no-color 2>&1 | tee reports/drift-$environment.txt
   # Exit codes: 0=no changes, 1=error, 2=drift detected
   ```

3. **Parse and classify changes**
   - `add` resources: new resources in code not in state
   - `change` resources: configuration drift
   - `destroy` resources: resources in state removed from code (HIGH RISK — alert immediately)

4. **If drift detected and `auto_pr=true`**:
   - Create branch `fix/drift-$environment-$(date +%Y%m%d)`
   - Commit updated tfvars if drift is a variable change
   - Open PR with plan diff as body

5. **Emit CloudWatch metric**
   ```bash
   aws cloudwatch put-metric-data \
     --namespace "Claude/Agent" \
     --metric-name "DriftDetected" \
     --value 1 \
     --dimensions Environment=$environment
   ```

## Output (JSON)
```json
{
  "status": "clean|drifted|error",
  "environment": "prod",
  "resources_to_add": 0,
  "resources_to_change": 2,
  "resources_to_destroy": 0,
  "drift_summary": "2 resources have configuration drift",
  "plan_url": "s3://tf-state-cicd-python-aws-ecs/drift-reports/prod-20260401.txt",
  "pr_url": null,
  "alert_sent": true
}
```

## Guardrails
- `destroy` drift on `prod` → page on-call immediately, DO NOT auto-apply
- `auto_pr=false` by default — requires explicit flag
- Plan output never contains secrets (Terraform masks sensitive values)
- All drift events logged to CloudWatch `/claude/agent` with full diff
