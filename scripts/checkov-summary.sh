#!/usr/bin/env bash
set -Eeuo pipefail

REPORTS_DIR="${REPORTS_DIR:-reports/checkov}"
JSON_REPORT="${CHECKOV_JSON_REPORT:-$REPORTS_DIR/checkov.json}"
SUMMARY_TXT="$REPORTS_DIR/summary.txt"
SUMMARY_MD="$REPORTS_DIR/summary.md"

mkdir -p "$REPORTS_DIR"

if [ ! -f "$JSON_REPORT" ]; then
  echo "Checkov JSON report not found at $JSON_REPORT" >"$SUMMARY_TXT"
  echo "### Checkov summary" >"$SUMMARY_MD"
  echo "- Checkov JSON report not found." >>"$SUMMARY_MD"
  exit 0
fi

python - "$JSON_REPORT" "$SUMMARY_TXT" "$SUMMARY_MD" <<'PY'
import json
import sys
from pathlib import Path

json_path = Path(sys.argv[1])
summary_txt_path = Path(sys.argv[2])
summary_md_path = Path(sys.argv[3])

data = json.loads(json_path.read_text(encoding="utf-8"))
if isinstance(data, list):
    report = data[0] if data else {}
else:
    report = data

summary = report.get("summary", {})
results = report.get("results", {})
failed_checks = results.get("failed_checks", [])

sev_counts = {}
for check in failed_checks:
    sev = (check.get("severity") or "UNKNOWN").upper()
    sev_counts[sev] = sev_counts.get(sev, 0) + 1

passed = int(summary.get("passed", 0))
failed = int(summary.get("failed", 0))
skipped = int(summary.get("skipped", 0))
parsing_errors = int(summary.get("parsing_errors", 0))
total = passed + failed
compliance = round((passed / total) * 100, 2) if total else 100.0

lines = [
    "=== Checkov Summary ===",
    f"Passed: {passed}",
    f"Failed: {failed}",
    f"Skipped: {skipped}",
    f"Parsing errors: {parsing_errors}",
    f"Compliance score: {compliance}%",
]
if sev_counts:
    lines.append("Failed checks by severity:")
    for sev in sorted(sev_counts):
        lines.append(f"  - {sev}: {sev_counts[sev]}")
summary_txt_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

md = [
    "### Checkov Summary",
    f"- Passed: **{passed}**",
    f"- Failed: **{failed}**",
    f"- Skipped: **{skipped}**",
    f"- Parsing errors: **{parsing_errors}**",
    f"- Compliance score: **{compliance}%**",
]
if sev_counts:
    md.append("- Failed checks by severity:")
    for sev in sorted(sev_counts):
        md.append(f"  - {sev}: {sev_counts[sev]}")
summary_md_path.write_text("\n".join(md) + "\n", encoding="utf-8")
PY

cat "$SUMMARY_TXT"
