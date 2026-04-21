#!/usr/bin/env bash
set -euo pipefail

# Bootstrap GitHub Actions OIDC trust and required IAM roles for this repository.
# Requires an AWS principal with IAM role/policy administration permissions.

AWS_PAGER=""
export AWS_PAGER

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
OWNER="${GITHUB_OWNER:-Suzuki3182}"
REPO="${GITHUB_REPO:-cicd_python_aws_ecs}"

OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

cat >/tmp/github-oidc-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${OWNER}/${REPO}:*"
        }
      }
    }
  ]
}
EOF

echo "==> Ensuring GitHub OIDC provider exists"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" >/dev/null 2>&1; then
  echo "    OIDC provider already exists: ${OIDC_PROVIDER_ARN}"
else
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
  echo "    Created OIDC provider: ${OIDC_PROVIDER_ARN}"
fi

ensure_role() {
  local role_name="$1"
  local policy_arn="$2"

  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    aws iam update-assume-role-policy \
      --role-name "$role_name" \
      --policy-document file:///tmp/github-oidc-trust.json
    echo "    Updated trust policy: ${role_name}"
  else
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document file:///tmp/github-oidc-trust.json \
      --description "GitHub Actions OIDC role: ${role_name}" >/dev/null
    echo "    Created role: ${role_name}"
  fi

  if aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='${policy_arn}'].PolicyArn" --output text | grep -q "$policy_arn"; then
    echo "    Policy already attached: ${role_name} -> ${policy_arn}"
  else
    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"
    echo "    Attached policy: ${role_name} -> ${policy_arn}"
  fi
}

echo "==> Ensuring required roles"
ensure_role "GitHubActions-Deploy" "arn:aws:iam::aws:policy/AdministratorAccess"
ensure_role "GitHubActions-ReadOnly" "arn:aws:iam::aws:policy/ReadOnlyAccess"
ensure_role "GitHubActions-SecretsRotation" "arn:aws:iam::aws:policy/SecretsManagerReadWrite"

echo "==> Verifying roles"
for role in GitHubActions-Deploy GitHubActions-ReadOnly GitHubActions-SecretsRotation; do
  echo "    $(aws iam get-role --role-name "$role" --query 'Role.Arn' --output text)"
done

echo "==> Done"
