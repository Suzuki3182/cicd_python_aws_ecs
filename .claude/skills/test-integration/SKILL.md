# Skill: test-integration

## Purpose
Run the full pytest suite (unit + integration) against a live or ephemeral environment. Enforce 90% coverage gate. Block merge on failure.

## Inputs
```json
{
  "environment": "dev|staging",
  "endpoint": "https://staging.example.com",
  "timeout": 300,
  "coverage_threshold": 90,
  "markers": "unit,integration"
}
```

## Execution Steps

1. **Install dependencies**
   ```bash
   cd src/app
   pip install -r requirements.txt -r requirements-dev.txt
   ```

2. **Unit tests**
   ```bash
   pytest tests/unit/ -v \
     --cov=app --cov-report=xml:reports/coverage-unit.xml \
     --cov-report=term-missing \
     --junitxml=reports/junit-unit.xml
   ```

3. **Integration tests** (requires live `$endpoint`)
   ```bash
   pytest tests/integration/ -v \
     --base-url=$endpoint \
     --timeout=$timeout \
     --junitxml=reports/junit-integration.xml
   ```

4. **Enforce coverage gate**
   ```bash
   coverage report --fail-under=$coverage_threshold
   ```

5. **Upload results** to S3 artifacts bucket

6. **Post results** to PR as structured comment

## Output (JSON)
```json
{
  "status": "passed|failed",
  "unit_tests": { "passed": 42, "failed": 0, "skipped": 2 },
  "integration_tests": { "passed": 15, "failed": 0 },
  "coverage_pct": 93.4,
  "coverage_threshold": 90,
  "gate_passed": true,
  "reports": {
    "coverage": "reports/coverage-unit.xml",
    "junit_unit": "reports/junit-unit.xml",
    "junit_integration": "reports/junit-integration.xml"
  }
}
```

## Guardrails
- Coverage below threshold → block merge, suggest missing test cases
- Integration tests only run against `dev` or `staging` (never prod)
- Flaky test detection: re-run failed tests once before marking as failed
- All test results logged to CloudWatch `/claude/agent`
