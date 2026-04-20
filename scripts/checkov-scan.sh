#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CHECKOV_CONFIG_FILE:-checkov-config.json}"
TF_DIR="${TF_DIR:-infrastructure/terraform}"
REPORTS_DIR="${REPORTS_DIR:-reports/checkov}"
FRAMEWORK="${CHECKOV_FRAMEWORK:-terraform}"
MAX_RETRIES="${CHECKOV_RETRIES:-3}"
RETRY_DELAY="${CHECKOV_RETRY_DELAY_SECONDS:-5}"

if [ -f "$CONFIG_FILE" ]; then
  TF_DIR="$(python - "$CONFIG_FILE" "$TF_DIR" <<'PY'
import json
import sys
path, default = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("directory", default))
PY
)"
  REPORTS_DIR="$(python - "$CONFIG_FILE" "$REPORTS_DIR" <<'PY'
import json
import sys
path, default = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("reports_dir", default))
PY
)"
  FRAMEWORK="$(python - "$CONFIG_FILE" "$FRAMEWORK" <<'PY'
import json
import sys
path, default = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("framework", default))
PY
)"
  MAX_RETRIES="$(python - "$CONFIG_FILE" "$MAX_RETRIES" <<'PY'
import json
import sys
path, default = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("retry", {}).get("max_attempts", default))
PY
)"
  RETRY_DELAY="$(python - "$CONFIG_FILE" "$RETRY_DELAY" <<'PY'
import json
import sys
path, default = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("retry", {}).get("delay_seconds", default))
PY
)"
fi

mkdir -p "$REPORTS_DIR"

CLI_REPORT="$REPORTS_DIR/checkov.cli"
JSON_REPORT="$REPORTS_DIR/checkov.json"
SARIF_REPORT="$REPORTS_DIR/checkov.sarif"
STATUS_FILE="$REPORTS_DIR/checkov-status.env"
RAW_REPORT_DIR="$REPORTS_DIR/raw"

if ! command -v checkov >/dev/null 2>&1; then
  echo "checkov not found; installing via pip"
  python -m pip install --upgrade pip
  python -m pip install "checkov>=3,<4"
fi

run_checkov() {
  local base_args=(
    -d "$TF_DIR"
    --framework "$FRAMEWORK"
    --soft-fail
    --config-file .checkov.yaml
  )
  local json_source
  local sarif_source

  rm -rf "$RAW_REPORT_DIR"
  mkdir -p "$RAW_REPORT_DIR"

  checkov "${base_args[@]}" --output cli | tee "$CLI_REPORT"
  checkov "${base_args[@]}" --output json --output-file-path "$RAW_REPORT_DIR"
  checkov "${base_args[@]}" --output sarif --output-file-path "$RAW_REPORT_DIR"

  json_source="$(find "$RAW_REPORT_DIR" -maxdepth 1 -type f -name '*json*.json' | head -n 1)"
  sarif_source="$(find "$RAW_REPORT_DIR" -maxdepth 1 -type f -name '*sarif*.sarif' | head -n 1)"

  [ -n "$json_source" ] && [ -f "$json_source" ] || return 1
  [ -n "$sarif_source" ] && [ -f "$sarif_source" ] || return 1

  cp "$json_source" "$JSON_REPORT"
  cp "$sarif_source" "$SARIF_REPORT"
  rm -rf "$RAW_REPORT_DIR"
}

attempt=1
scan_success=0
while [ "$attempt" -le "$MAX_RETRIES" ]; do
  echo "==> Running Checkov attempt $attempt/$MAX_RETRIES"
  if run_checkov; then
    scan_success=1
    break
  fi
  echo "WARN: Checkov attempt $attempt failed"
  if [ "$attempt" -lt "$MAX_RETRIES" ]; then
    sleep "$RETRY_DELAY"
  fi
  attempt=$((attempt + 1))
done

if [ "$scan_success" -eq 0 ]; then
  echo "WARN: Checkov failed after $MAX_RETRIES attempts. Writing fallback report."
  {
    echo "CHECKOV_SCAN_SUCCESS=false"
    echo "CHECKOV_SCAN_ERROR=Checkov failed after retries"
  } >"$STATUS_FILE"

  cat >"$JSON_REPORT" <<'EOF'
{"summary":{"passed":0,"failed":0,"skipped":0,"parsing_errors":1},"results":{"failed_checks":[],"passed_checks":[],"skipped_checks":[]}}
EOF
  printf '{"version":"2.1.0","runs":[]}' >"$SARIF_REPORT"
  echo "Checkov failed after retries; fallback report generated." >"$CLI_REPORT"
  exit 0
fi

{
  echo "CHECKOV_SCAN_SUCCESS=true"
  echo "CHECKOV_SCAN_ERROR="
} >"$STATUS_FILE"

echo "Checkov scan completed. Reports available in $REPORTS_DIR"
