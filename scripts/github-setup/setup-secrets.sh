#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-secrets.sh [--repo owner/name] [--account-id 123456789012] [--staging-url URL] [--prod-url URL] [--ecr-registry URL]
EOF
}

REPO="${GITHUB_REPOSITORY:-}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
STAGING_URL="${STAGING_URL:-}"
PROD_URL="${PROD_URL:-}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --account-id)
      AWS_ACCOUNT_ID="${2:-}"
      shift 2
      ;;
    --staging-url)
      STAGING_URL="${2:-}"
      shift 2
      ;;
    --prod-url)
      PROD_URL="${2:-}"
      shift 2
      ;;
    --ecr-registry)
      ECR_REGISTRY="${2:-}"
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

if [ -z "$REPO" ]; then
  REPO="$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi
[ -n "$REPO" ] || { echo "Repository is required (set GITHUB_REPOSITORY or --repo)." >&2; exit 1; }

if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
fi

[[ "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || { echo "AWS_ACCOUNT_ID must be a 12-digit account id." >&2; exit 1; }
[ -n "$STAGING_URL" ] || { echo "STAGING_URL is required." >&2; exit 1; }
[ -n "$PROD_URL" ] || { echo "PROD_URL is required." >&2; exit 1; }

if [ -z "$ECR_REGISTRY" ]; then
  ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  exit 1
fi

gh auth status >/dev/null
gh repo view "$REPO" >/dev/null

set_secret() {
  local name="$1"
  local value="$2"
  printf '%s' "$value" | gh secret set "$name" --repo "$REPO" --body -
}

set_secret "AWS_ACCOUNT_ID" "$AWS_ACCOUNT_ID"
set_secret "STAGING_URL" "$STAGING_URL"
set_secret "PROD_URL" "$PROD_URL"
set_secret "ECR_REGISTRY" "$ECR_REGISTRY"

REQUIRED=("AWS_ACCOUNT_ID" "STAGING_URL" "PROD_URL" "ECR_REGISTRY")
SECRET_LIST="$(gh secret list --repo "$REPO" --limit 200 | awk '{print $1}')"
for secret_name in "${REQUIRED[@]}"; do
  echo "$SECRET_LIST" | grep -qx "$secret_name" || {
    echo "Failed to validate secret ${secret_name}" >&2
    exit 1
  }
done

if ! bash "$(dirname "${BASH_SOURCE[0]}")/../aws-setup/verify-oidc.sh" \
  --repo "$REPO" \
  --account-id "$AWS_ACCOUNT_ID"; then
  echo "OIDC verification failed after setting secrets. Check provider/roles/trust policy setup." >&2
  exit 1
fi

echo "GitHub secrets are configured and OIDC setup validation passed."
