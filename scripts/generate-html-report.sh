#!/usr/bin/env bash
set -Eeuo pipefail

REPORTS_DIR="${REPORTS_DIR:-reports/checkov}"
JSON_REPORT="${CHECKOV_JSON_REPORT:-$REPORTS_DIR/checkov.json}"
HTML_REPORT="${CHECKOV_HTML_REPORT:-$REPORTS_DIR/checkov.html}"
HISTORY_FILE="${CHECKOV_HISTORY_FILE:-$REPORTS_DIR/history.json}"

mkdir -p "$REPORTS_DIR"

if [ ! -f "$JSON_REPORT" ]; then
  cat >"$HTML_REPORT" <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Checkov Report</title></head>
<body><h1>Checkov Report</h1><p>JSON report not found.</p></body>
</html>
EOF
  exit 0
fi

python - "$JSON_REPORT" "$HTML_REPORT" "$HISTORY_FILE" <<'PY'
import html
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

json_path = Path(sys.argv[1])
html_path = Path(sys.argv[2])
history_path = Path(sys.argv[3])

data = json.loads(json_path.read_text(encoding="utf-8"))
report = data[0] if isinstance(data, list) and data else (data if isinstance(data, dict) else {})
summary = report.get("summary", {})
failed_checks = report.get("results", {}).get("failed_checks", [])

passed = int(summary.get("passed", 0))
failed = int(summary.get("failed", 0))
skipped = int(summary.get("skipped", 0))
parsing_errors = int(summary.get("parsing_errors", 0))
total = passed + failed
compliance = round((passed / total) * 100, 2) if total else 100.0
status = "PASS" if failed == 0 and parsing_errors == 0 else "FAIL"

severity_counts = {}
for check in failed_checks:
    sev = (check.get("severity") or "UNKNOWN").upper()
    severity_counts[sev] = severity_counts.get(sev, 0) + 1

history = []
if history_path.exists():
    try:
        history = json.loads(history_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        history = []

current_entry = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "passed": passed,
    "failed": failed,
    "skipped": skipped,
    "parsing_errors": parsing_errors,
    "compliance": compliance,
}
history.append(current_entry)
history = history[-20:]
history_path.write_text(json.dumps(history, indent=2), encoding="utf-8")

history_rows = "\n".join(
    f"<tr><td>{html.escape(item['timestamp'])}</td><td>{item['passed']}</td><td>{item['failed']}</td><td>{item['compliance']}%</td></tr>"
    for item in history
)

failed_rows = []
for check in failed_checks:
    failed_rows.append(
        "<tr>"
        f"<td>{html.escape(str(check.get('check_id', '')))}</td>"
        f"<td>{html.escape(str(check.get('check_name', '')))}</td>"
        f"<td>{html.escape(str(check.get('severity', 'UNKNOWN')))}</td>"
        f"<td>{html.escape(str(check.get('file_path', '')))}:{html.escape(str(check.get('file_line_range', '')))}</td>"
        f"<td>{html.escape(str(check.get('resource', '')))}</td>"
        f"<td>{html.escape(str(check.get('guideline', 'N/A')))}</td>"
        "</tr>"
    )

if not failed_rows:
    failed_rows = ['<tr><td colspan="6">No failed checks.</td></tr>']

severity_items = "".join(
    f"<li>{html.escape(level)}: {count}</li>" for level, count in sorted(severity_counts.items())
) or "<li>No failed checks</li>"

report_html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Checkov Terraform Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    .status-pass {{ color: #0a7a2f; font-weight: bold; }}
    .status-fail {{ color: #b42318; font-weight: bold; }}
    .cards {{ display: flex; gap: 12px; flex-wrap: wrap; }}
    .card {{ border: 1px solid #ddd; border-radius: 8px; padding: 12px 16px; min-width: 150px; }}
    table {{ border-collapse: collapse; width: 100%; margin-top: 12px; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }}
    th {{ background: #f3f4f6; }}
  </style>
</head>
<body>
  <h1>Checkov Terraform Report</h1>
  <p>Status: <span class="status-{'pass' if status == 'PASS' else 'fail'}">{status}</span></p>
  <div class="cards">
    <div class="card"><strong>Compliance</strong><br>{compliance}%</div>
    <div class="card"><strong>Passed</strong><br>{passed}</div>
    <div class="card"><strong>Failed</strong><br>{failed}</div>
    <div class="card"><strong>Skipped</strong><br>{skipped}</div>
    <div class="card"><strong>Parsing Errors</strong><br>{parsing_errors}</div>
  </div>

  <h2>Severity Breakdown</h2>
  <ul>{severity_items}</ul>

  <h2>Failed Checks (with remediation guidance)</h2>
  <table>
    <thead>
      <tr><th>Check ID</th><th>Name</th><th>Severity</th><th>File</th><th>Resource</th><th>Guideline</th></tr>
    </thead>
    <tbody>
      {''.join(failed_rows)}
    </tbody>
  </table>

  <h2>Findings Trend</h2>
  <table>
    <thead><tr><th>Timestamp (UTC)</th><th>Passed</th><th>Failed</th><th>Compliance</th></tr></thead>
    <tbody>{history_rows}</tbody>
  </table>
</body>
</html>
"""
html_path.write_text(report_html, encoding="utf-8")
PY

echo "Generated HTML report: $HTML_REPORT"
