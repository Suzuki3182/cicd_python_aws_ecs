#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-token.actions.githubusercontent.com}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required" >&2
  exit 1
fi

THUMBPRINT="$(
  openssl s_client -servername "$HOST" -connect "$HOST:443" -showcerts </dev/null 2>/dev/null \
    | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{print}' \
    | awk 'BEGIN {cert=""} /BEGIN CERTIFICATE/ {cert=$0 ORS; next} /END CERTIFICATE/ {cert=cert $0 ORS; last=cert; next} {cert=cert $0 ORS} END {printf "%s", last}' \
    | openssl x509 -fingerprint -sha1 -noout \
    | awk -F= '{print $2}' \
    | tr -d ':'
)"

if [ -z "${THUMBPRINT:-}" ]; then
  echo "Failed to retrieve thumbprint for $HOST" >&2
  exit 1
fi

echo "$THUMBPRINT"
