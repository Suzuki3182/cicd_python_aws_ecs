#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verify-oidc.sh [--repo owner/name] [--account-id 123456789012]
EOF
}

REPO="${GITHUB_REPOSITORY:-}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --account-id)
      ACCOUNT_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$ACCOUNT_ID" ]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
fi

if [ -z "$REPO" ]; then
  REPO="$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" >/dev/null

for role in GitHubActions-Deploy GitHubActions-ReadOnly GitHubActions-SecretsRotation; do
  TRUST_JSON="$(aws iam get-role --role-name "$role" --query 'Role.AssumeRolePolicyDocument' --output json)"
  echo "$TRUST_JSON" | grep -q "repo:${REPO}:\\*" || {
    echo "Role ${role} trust policy does not include repo:${REPO}:*" >&2
    exit 1
  }
done

echo "OIDC provider and IAM role trust policies verified for ${REPO}."
