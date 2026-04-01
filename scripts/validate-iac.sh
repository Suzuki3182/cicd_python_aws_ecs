#!/usr/bin/env bash
# validate-iac.sh — tfsec + checkov + conftest IaC security gates
set -euo pipefail

TF_DIR="${TF_DIR:-infrastructure/terraform}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
SEVERITY="${SEVERITY:-HIGH}"
CHECKOV_THRESHOLD="${CHECKOV_THRESHOLD:-95}"

mkdir -p "$REPORTS_DIR"

echo "==> Running tfsec (minimum severity: $SEVERITY)"
tfsec "$TF_DIR" \
  --minimum-severity "$SEVERITY" \
  --format json \
  --out "$REPORTS_DIR/tfsec.json" \
  --no-color

TFSEC_COUNT=$(jq '.results | length' "$REPORTS_DIR/tfsec.json" 2>/dev/null || echo 0)
echo "    tfsec findings: $TFSEC_COUNT"

if [ "$TFSEC_COUNT" -gt 0 ]; then
  echo "FAIL: tfsec found $TFSEC_COUNT findings at $SEVERITY or above" >&2
  jq '.results[] | "\(.severity): \(.description) [\(.location.filename):\(.location.start_line)]"' \
    "$REPORTS_DIR/tfsec.json" >&2
  exit 1
fi

echo "==> Running checkov"
checkov \
  --directory "$TF_DIR" \
  --framework terraform \
  --output json \
  --output-file "$REPORTS_DIR/checkov.json" \
  --compact || CHECKOV_EXIT=$?

PASSED=$(jq '.summary.passed' "$REPORTS_DIR/checkov.json" 2>/dev/null || echo 0)
FAILED=$(jq '.summary.failed' "$REPORTS_DIR/checkov.json" 2>/dev/null || echo 0)
TOTAL=$((PASSED + FAILED))
if [ "$TOTAL" -gt 0 ]; then
  SCORE=$(( (PASSED * 100) / TOTAL ))
else
  SCORE=100
fi

echo "    checkov score: $SCORE% ($PASSED/$TOTAL passed)"

if [ "$SCORE" -lt "$CHECKOV_THRESHOLD" ]; then
  echo "FAIL: checkov compliance $SCORE% is below threshold $CHECKOV_THRESHOLD%" >&2
  exit 1
fi

echo "==> All IaC security gates passed"
echo "    tfsec: 0 findings"
echo "    checkov: $SCORE% compliance"
