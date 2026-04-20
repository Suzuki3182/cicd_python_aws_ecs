#!/usr/bin/env bash
# smoke-test-eks.sh — validates EKS rollout health before full cutover
set -euo pipefail

NAMESPACE="app"
DEPLOYMENT=""
SERVICE=""
TIMEOUT=300
HEALTH_PATH="/health"
LOCAL_PORT=18080
EXTERNAL_ENDPOINT=""
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace=*) NAMESPACE="${1#*=}"; shift ;;
    --deployment=*) DEPLOYMENT="${1#*=}"; shift ;;
    --service=*) SERVICE="${1#*=}"; shift ;;
    --timeout=*) TIMEOUT="${1#*=}"; shift ;;
    --health-path=*) HEALTH_PATH="${1#*=}"; shift ;;
    --local-port=*) LOCAL_PORT="${1#*=}"; shift ;;
    --endpoint=*) EXTERNAL_ENDPOINT="${1#*=}"; shift ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$DEPLOYMENT" || -z "$SERVICE" ]]; then
  echo "Usage: $0 --deployment=<name> --service=<name> [--namespace=app] [--timeout=300] [--health-path=/health] [--local-port=18080] [--endpoint=https://...]" >&2
  exit 1
fi

for cmd in kubectl curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: required command '$cmd' not found in PATH" >&2
    exit 1
  fi
done

echo "==> EKS smoke test"
echo "    namespace: $NAMESPACE"
echo "    deployment: $DEPLOYMENT"
echo "    service: $SERVICE"
echo "    health path: $HEALTH_PATH"
echo "    timeout: ${TIMEOUT}s"

kubectl -n "$NAMESPACE" rollout status "deployment/$DEPLOYMENT" --timeout="${TIMEOUT}s"

PF_LOG="/tmp/eks-port-forward-${DEPLOYMENT}.log"
kubectl -n "$NAMESPACE" port-forward "service/$SERVICE" "${LOCAL_PORT}:80" >"$PF_LOG" 2>&1 &
PF_PID=$!

cleanup() {
  if kill -0 "$PF_PID" >/dev/null 2>&1; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

ELAPSED=0
LOCAL_URL="http://127.0.0.1:${LOCAL_PORT}${HEALTH_PATH}"
until curl -sf --max-time 5 "$LOCAL_URL" >/tmp/eks-smoke-response.json; do
  if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
    echo "FAIL: local service health check timed out at ${TIMEOUT}s ($LOCAL_URL)" >&2
    echo "Port-forward logs:" >&2
    tail -n 50 "$PF_LOG" >&2 || true
    exit 1
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

STATUS=$(jq -r '.status // "healthy"' /tmp/eks-smoke-response.json 2>/dev/null || echo "healthy")
if [[ "$STATUS" != "healthy" ]]; then
  echo "FAIL: service returned unhealthy status='$STATUS'" >&2
  echo "Response: $(cat /tmp/eks-smoke-response.json)" >&2
  exit 1
fi

if [[ -n "$EXTERNAL_ENDPOINT" ]]; then
  echo "==> Validating external endpoint: $EXTERNAL_ENDPOINT"
  ELAPSED=0
  until curl -sf --max-time 5 "$EXTERNAL_ENDPOINT" >/tmp/eks-smoke-external.json; do
    if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
      echo "FAIL: external endpoint health check timed out at ${TIMEOUT}s" >&2
      exit 1
    fi
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
  done

  EXTERNAL_STATUS=$(jq -r '.status // "healthy"' /tmp/eks-smoke-external.json 2>/dev/null || echo "healthy")
  if [[ "$EXTERNAL_STATUS" != "healthy" ]]; then
    echo "FAIL: external endpoint returned status='$EXTERNAL_STATUS'" >&2
    echo "Response: $(cat /tmp/eks-smoke-external.json)" >&2
    exit 1
  fi
fi

echo "==> EKS smoke test passed"