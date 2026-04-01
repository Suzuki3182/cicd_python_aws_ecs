# Skill: scan-security

## Purpose
Run SCA (dependency), SAST (code), container image, and IaC security scans. Block on CRITICAL findings; annotate PRs with results.

## Inputs
```json
{
  "target": "src/|infrastructure/terraform/|.",
  "level": "critical|high|medium",
  "image_uri": "123456789.dkr.ecr.us-east-1.amazonaws.com/app:sha-abc123",
  "fail_on_critical": true
}
```

## Execution Steps

1. **SCA — Python dependencies**
   ```bash
   pip-audit -r src/app/requirements.txt --format json -o reports/sca.json
   safety check -r src/app/requirements.txt --json > reports/safety.json
   ```

2. **SAST — Static code analysis**
   ```bash
   bandit -r src/app/ -f json -o reports/bandit.json -l
   semgrep --config=p/python --config=p/owasp-top-ten \
           --json -o reports/semgrep.json src/app/
   ```

3. **Container image scan**
   ```bash
   trivy image --severity CRITICAL,HIGH \
               --format json -o reports/trivy-image.json \
               $image_uri
   ```

4. **IaC scan**
   ```bash
   tfsec infrastructure/terraform/ --format json \
         --out reports/tfsec.json --minimum-severity HIGH
   checkov -d infrastructure/terraform/ --output json \
           --output-file reports/checkov.json
   ```

5. **Secrets scan**
   ```bash
   trufflesecurity/trufflehog filesystem . --json > reports/secrets.json
   ```

6. **Aggregate results** and evaluate gates:
   - CRITICAL vulnerabilities → fail immediately
   - HIGH vulnerabilities → fail if `level=high`
   - Post structured comment to PR

## Output (JSON)
```json
{
  "status": "passed|failed",
  "critical_count": 0,
  "high_count": 2,
  "gates_passed": true,
  "reports": {
    "sca":     "reports/sca.json",
    "sast":    "reports/bandit.json",
    "container": "reports/trivy-image.json",
    "iac":     "reports/tfsec.json",
    "secrets": "reports/secrets.json"
  },
  "blocking_findings": []
}
```

## Guardrails
- Always runs before any deployment
- `prod` deployment blocked if `critical_count > 0`
- Reports archived to S3 artifacts bucket for compliance audit trail
- Findings logged to CloudWatch `/claude/agent`
