#!/usr/bin/env bash
# bootstrap.sh — one-time environment setup
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-tf-state-cicd-python-aws-ecs}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:-tf-state-lock}"

echo "==> Creating S3 backend bucket: $TF_STATE_BUCKET"
if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" >/dev/null 2>&1; then
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$TF_STATE_BUCKET" \
      --region "$AWS_REGION"
  else
    aws s3api create-bucket \
      --bucket "$TF_STATE_BUCKET" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
fi

aws s3api put-bucket-versioning \
  --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Creating DynamoDB lock table: $TF_LOCK_TABLE"
aws dynamodb create-table \
  --table-name "$TF_LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION" 2>/dev/null || true

echo "==> Initializing Terraform workspaces"
cd infrastructure/terraform
terraform init -reconfigure
for env in dev staging prod; do
  terraform workspace new "$env" 2>/dev/null || true
done

echo "==> Bootstrap complete"
echo "    State bucket : $TF_STATE_BUCKET"
echo "    Lock table   : $TF_LOCK_TABLE"
