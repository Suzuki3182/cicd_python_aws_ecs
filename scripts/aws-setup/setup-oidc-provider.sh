#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_HOST="token.actions.githubusercontent.com"
CLIENT_ID="sts.amazonaws.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required" >&2
  exit 1
fi

THUMBPRINT="$("$SCRIPT_DIR/get-thumbprint.sh" "$OIDC_HOST")"

ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" >/dev/null 2>&1; then
  echo "OIDC provider already exists, updating thumbprint..."
  aws iam update-open-id-connect-provider-thumbprint \
    --open-id-connect-provider-arn "$PROVIDER_ARN" \
    --thumbprint-list "$THUMBPRINT" >/dev/null
else
  echo "Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "$OIDC_URL" \
    --client-id-list "$CLIENT_ID" \
    --thumbprint-list "$THUMBPRINT" >/dev/null
fi

echo "OIDC provider configured: $PROVIDER_ARN"
echo "Thumbprint: $THUMBPRINT"
echo "Region: $AWS_REGION"
