#!/usr/bin/env bash
# auto-rollback.sh — CloudWatch alarm → ECS rollback to previous image tag
set -euo pipefail

ENV="${1:-}"
CLUSTER="${2:-}"

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --env=*)    ENV="${1#*=}";     shift ;;
    --cluster=*) CLUSTER="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$ENV" || -z "$CLUSTER" ]]; then
  echo "Usage: $0 --env=<environment> --cluster=<ecs-cluster-name>" >&2
  exit 1
fi

SERVICE="cicd-python-ecs-$ENV"
TF_DIR="infrastructure/terraform"

echo "==> Fetching current task definition"
CURRENT_TD=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query "services[0].taskDefinition" \
  --output text)

CURRENT_REVISION=$(echo "$CURRENT_TD" | grep -oE '[0-9]+$')
PREVIOUS_REVISION=$((CURRENT_REVISION - 1))

echo "    Current revision : $CURRENT_REVISION"
echo "    Rollback target  : $PREVIOUS_REVISION"

if [ "$PREVIOUS_REVISION" -lt 1 ]; then
  echo "ERROR: No previous revision available for rollback" >&2
  exit 1
fi

FAMILY=$(echo "$CURRENT_TD" | cut -d: -f6 | cut -d/ -f2)
PREVIOUS_IMAGE=$(aws ecs describe-task-definition \
  --task-definition "${FAMILY}:${PREVIOUS_REVISION}" \
  --query "taskDefinition.containerDefinitions[0].image" \
  --output text)

PREVIOUS_TAG=$(echo "$PREVIOUS_IMAGE" | cut -d: -f2)
echo "    Rolling back to image tag: $PREVIOUS_TAG"

echo "==> Applying rollback via Terraform"
cd "$TF_DIR"
terraform workspace select "$ENV"
terraform apply \
  -var-file="environments/$ENV.tfvars" \
  -var="image_tag=$PREVIOUS_TAG" \
  -auto-approve

echo "==> Waiting for ECS service to stabilize"
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE"

echo "==> Emitting rollback metric to CloudWatch"
aws cloudwatch put-metric-data \
  --namespace "Claude/Agent" \
  --metric-name "AutoRollback" \
  --value 1 \
  --dimensions Environment="$ENV"

echo "==> Rollback complete: $ENV now running $PREVIOUS_TAG"
