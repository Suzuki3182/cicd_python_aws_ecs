# Create the role with trust policy
aws iam create-role \
  --role-name GitHubActions-Deploy-Role \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --description "Role assumed by GitHub Actions via OIDC"

# Attach permissions (example: read-only S3)
aws iam attach-role-policy \
  --role-name GitHubActions-Deploy-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Or attach a custom policy (recommended for least privilege)
aws iam put-role-policy \
  --role-name GitHubActions-Deploy-Role \
  --policy-name GitHubActions-Custom \
  --policy-document file:///tmp/custom-permissions.json
