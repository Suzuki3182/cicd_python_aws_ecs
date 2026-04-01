#!/usr/bin/env bash
# smoke-test.sh — post-deploy health validation
set -euo pipefail

ENV=""
ENDPOINT=""
TIMEOUT=300
INTERVAL=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --env=*)      ENV="${1#*=}";      shift ;;
    --endpoint=*) ENDPOINT="${1#*=}"; shift ;;
    --timeout=*)  TIMEOUT="${1#*=}";  shift ;;
    *) shift ;;
  esac
done

if [[ -z "$ENDPOINT" ]]; then
  echo "Usage: $0 --endpoint=<url> [--env=<env>] [--timeout=<seconds>]" >&2
  exit 1
fi

echo "==> Smoke test: $ENDPOINT (timeout: ${TIMEOUT}s, env: ${ENV:-unknown})"

ELAPSED=0
until curl -sf --max-time 5 "$ENDPOINT" > /tmp/smoke-response.json; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "FAIL: health check timed out after ${TIMEOUT}s" >&2
    exit 1
  fi
  echo "    waiting... ${ELAPSED}s elapsed"
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

STATUS=$(jq -r '.status // "unknown"' /tmp/smoke-response.json 2>/dev/null || echo "unknown")
echo "    Response: $(cat /tmp/smoke-response.json)"

if [[ "$STATUS" != "healthy" ]]; then
  echo "FAIL: health endpoint returned status='$STATUS'" >&2
  exit 1
fi

echo "==> Smoke test passed in ${ELAPSED}s"
