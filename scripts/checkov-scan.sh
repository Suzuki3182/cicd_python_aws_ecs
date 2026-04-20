#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CHECKOV_CONFIG_FILE:-checkov-config.json}"
TF_DIR="${TF_DIR:-infrastructure/terraform}"
REPORTS_DIR="${REPORTS_DIR:-reports/checkov}"
FRAMEWORK="${CHECKOV_FRAMEWORK:-terraform}"
MAX_RETRIES="${CHECKOV_RETRIES:-3}"
RETRY_DELAY="${CHECKOV_RETRY_DELAY_SECONDS:-5}"

read_config_value() {
  local key="$1"
  local default="$2"

  python - "$CONFIG_FILE" "$key" "$default" <<'PY'
import json
import sys

path, key_path, default = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as config_file:
    data = json.load(config_file)

value = data
for part in key_path.split("."):
    if not isinstance(value, dict) or part not in value:
        print(default)
        raise SystemExit(0)
    value = value[part]

print(value)
PY
}

if [ -f "$CONFIG_FILE" ]; then
  TF_DIR="$(read_config_value "directory" "$TF_DIR")"
  REPORTS_DIR="$(read_config_value "reports_dir" "$REPORTS_DIR")"
  FRAMEWORK="$(read_config_value "framework" "$FRAMEWORK")"
  MAX_RETRIES="$(read_config_value "retry.max_attempts" "$MAX_RETRIES")"
  RETRY_DELAY="$(read_config_value "retry.delay_seconds" "$RETRY_DELAY")"
fi

mkdir -p "$REPORTS_DIR"

CLI_REPORT="$REPORTS_DIR/checkov.cli"
JSON_REPORT="$REPORTS_DIR/checkov.json"
SARIF_REPORT="$REPORTS_DIR/checkov.sarif"
STATUS_FILE="$REPORTS_DIR/checkov-status.env"
RAW_REPORT_DIR="$REPORTS_DIR/raw"

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

  # Checkov currently emits files like results_json.json and results_sarif.sarif when output path is a directory.
  json_source="$(find "$RAW_REPORT_DIR" -maxdepth 1 -type f -name 'results_json*.json' | head -n 1)"
  sarif_source="$(find "$RAW_REPORT_DIR" -maxdepth 1 -type f -name 'results_sarif*.sarif' | head -n 1)"

  if [ -z "$json_source" ] || [ ! -f "$json_source" ]; then
    echo "WARN: expected Checkov JSON output not found in $RAW_REPORT_DIR"
    return 1
  fi
  if [ -z "$sarif_source" ] || [ ! -f "$sarif_source" ]; then
    echo "WARN: expected Checkov SARIF output not found in $RAW_REPORT_DIR"
    return 1
  fi

  cp "$json_source" "$JSON_REPORT"
  cp "$sarif_source" "$SARIF_REPORT"
  rm -rf "$RAW_REPORT_DIR"
}

attempt=1
scan_succeeded=0
while [ "$attempt" -le "$MAX_RETRIES" ]; do
  echo "==> Running Checkov attempt $attempt/$MAX_RETRIES"
  if run_checkov; then
    scan_succeeded=1
    break
  fi
  echo "WARN: Checkov attempt $attempt failed"
  if [ "$attempt" -lt "$MAX_RETRIES" ]; then
    sleep "$RETRY_DELAY"
  fi
  attempt=$((attempt + 1))
done

if [ "$scan_succeeded" -eq 0 ]; then
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
