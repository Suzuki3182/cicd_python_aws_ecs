# Checkov Configuration

This repository keeps Checkov settings in `.checkov.yaml` at the repository root.

## What is configured

- `framework: terraform` for IaC modules under `infrastructure/terraform`
- `soft-fail: true` for initial rollout (report findings without blocking CI)
- output formats for CLI, JSON, and SARIF
- baseline file at `.checkov.baseline.json` to track incremental improvements
- centralized skip rules for known policy exceptions

## Suppressing checks

Prefer fixing findings first. If a check must be suppressed:

1. Add a documented repository-level exception in `.checkov.yaml` under `skip-check`:

   ```yaml
   skip-check:
     - CKV_AWS_123:reason for exception
   ```

2. Or add an inline suppression on a specific Terraform block:

   ```hcl
   #checkov:skip=CKV_AWS_123:reason for exception
   resource "aws_s3_bucket" "example" {
     # ...
   }
   ```

Always include a short business/security rationale.

## Baseline generation

Regenerate the baseline when accepted findings change:

```bash
bash scripts/generate-checkov-baseline.sh
```

This updates `.checkov.baseline.json` and writes a JSON report to `reports/checkov-baseline-report.json`.
