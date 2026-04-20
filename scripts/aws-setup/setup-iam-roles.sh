#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-iam-roles.sh [--repo owner/name] [--account-id 123456789012]
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

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required" >&2
  exit 1
fi

if [ -z "$REPO" ]; then
  REPO="$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

[ -n "$REPO" ] || { echo "Repository is required (set GITHUB_REPOSITORY or --repo)." >&2; exit 1; }
[[ "$REPO" == */* ]] || { echo "Repository must be in owner/name format: $REPO" >&2; exit 1; }

if [ -z "$ACCOUNT_ID" ]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
fi

[[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || { echo "Invalid AWS account id: $ACCOUNT_ID" >&2; exit 1; }

OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

create_trust_policy() {
  local role_name="$1"
  local trust_file="$2"
  cat > "$trust_file" <<EOF
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
          "token.actions.githubusercontent.com:sub": "repo:${REPO}:*"
        }
      }
    }
  ]
}
EOF
}

attach_managed_policy_if_missing() {
  local role_name="$1"
  local policy_arn="$2"
  if ! aws iam list-attached-role-policies --role-name "$role_name" \
    --query "AttachedPolicies[?PolicyArn=='$policy_arn']" --output text | grep -q "$policy_arn"; then
    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" >/dev/null
  fi
}

upsert_role() {
  local role_name="$1"
  shift
  local trust_file="/tmp/${role_name}-trust-policy.json"
  create_trust_policy "$role_name" "$trust_file"

  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    aws iam update-assume-role-policy \
      --role-name "$role_name" \
      --policy-document "file://${trust_file}" >/dev/null
  else
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document "file://${trust_file}" \
      --description "GitHub Actions OIDC role for ${role_name}" >/dev/null
  fi

  for managed_policy in "$@"; do
    attach_managed_policy_if_missing "$role_name" "$managed_policy"
  done

  rm -f "$trust_file"
}

echo "Configuring IAM roles for repository: $REPO"

upsert_role \
  "GitHubActions-Deploy" \
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser" \
  "arn:aws:iam::aws:policy/AmazonECS_FullAccess" \
  "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" \
  "arn:aws:iam::aws:policy/SecretsManagerReadWrite"

upsert_role \
  "GitHubActions-ReadOnly" \
  "arn:aws:iam::aws:policy/ReadOnlyAccess"

upsert_role \
  "GitHubActions-SecretsRotation" \
  "arn:aws:iam::aws:policy/SecretsManagerReadWrite" \
  "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"

echo "IAM roles configured successfully for account ${ACCOUNT_ID}."
