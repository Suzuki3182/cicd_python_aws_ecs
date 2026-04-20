#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECKOV_IMAGE="${CHECKOV_IMAGE:-bridgecrew/checkov:3.2.524}"
BASELINE_FILE="${BASELINE_FILE:-.checkov.baseline.json}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
GENERATED_BASELINE="${GENERATED_BASELINE:-infrastructure/terraform/.checkov.baseline}"

mkdir -p "$REPO_ROOT/$REPORTS_DIR"
if [ ! -f "$REPO_ROOT/$BASELINE_FILE" ]; then
  printf '{"failed_checks":[]}\n' >"$REPO_ROOT/$BASELINE_FILE"
fi

run_checkov() {
  "$@" \
    --directory infrastructure/terraform \
    --framework terraform \
    --config-file .checkov.yaml \
    --create-baseline \
    --baseline "$BASELINE_FILE" \
    --output cli \
    --output json \
    --output-file-path console,"$REPORTS_DIR/checkov-baseline-report.json" \
    --soft-fail
}

if command -v docker >/dev/null 2>&1; then
  (
    cd "$REPO_ROOT"
    run_checkov docker run --rm -v "$REPO_ROOT:/repo" -w /repo "$CHECKOV_IMAGE"
  )
elif command -v checkov >/dev/null 2>&1; then
  (
    cd "$REPO_ROOT"
    run_checkov checkov
  )
else
  echo "ERROR: neither docker nor checkov CLI is available." >&2
  exit 1
fi

if [ -f "$REPO_ROOT/$GENERATED_BASELINE" ]; then
  cp "$REPO_ROOT/$GENERATED_BASELINE" "$REPO_ROOT/$BASELINE_FILE"
  rm -f "$REPO_ROOT/$GENERATED_BASELINE"
fi

echo "Baseline updated: $REPO_ROOT/$BASELINE_FILE"
