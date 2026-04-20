# CI/CD Troubleshooting

## Error: `Could not assume role with OIDC: Request ARN is invalid`

### Cause

`AWS_ACCOUNT_ID` was missing/empty, producing an invalid ARN like:

`arn:aws:iam:::role/GitHubActions-Deploy`

### Fix

1. Set required secrets in the repository:
   - `AWS_ACCOUNT_ID`
   - `STAGING_URL`
   - `PROD_URL`
   - `ECR_REGISTRY`
2. Ensure OIDC provider exists in AWS IAM.
3. Ensure roles exist:
   - `GitHubActions-Deploy`
   - `GitHubActions-ReadOnly`
   - `GitHubActions-SecretsRotation`
4. Verify trust policy includes `repo:<OWNER>/<REPO>:*`.

## Fast recovery commands

```bash
cd <repo-root>
bash scripts/aws-setup/setup-oidc-provider.sh
bash scripts/aws-setup/setup-iam-roles.sh --repo <OWNER>/<REPO>
bash scripts/github-setup/setup-secrets.sh --repo <OWNER>/<REPO>
```

## Validation commands

```bash
bash scripts/aws-setup/verify-oidc.sh --repo <OWNER>/<REPO>
gh secret list --repo <OWNER>/<REPO>
```

## Other common failures

- `NoCredentials` during rollback:
  - Root cause: AWS OIDC step failed first, so rollback has no credentials.
  - Fix: resolve OIDC ARN/trust setup and rerun workflow.
- `AWS_ACCOUNT_ID secret must be a 12-digit account ID`:
  - Secret value is missing or malformed. Update it in repository secrets.
