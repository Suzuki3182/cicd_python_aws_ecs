#!/usr/bin/env bash
set -Eeuo pipefail

REPORTS_DIR="${REPORTS_DIR:-reports/checkov}"
MANIFEST_FILE="$REPORTS_DIR/manifest.txt"

mkdir -p "$REPORTS_DIR"

{
  echo "Checkov report artifacts"
  echo "Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  for file in checkov.cli checkov.json checkov.sarif checkov.html summary.txt summary.md history.json checkov-status.env; do
    if [ -f "$REPORTS_DIR/$file" ]; then
      echo " - $file"
    fi
  done
} >"$MANIFEST_FILE"

echo "Prepared Checkov artifacts:"
cat "$MANIFEST_FILE"
