#!/usr/bin/env bash
# pin_cert.sh — Extract SHA-256 fingerprint from a VPS TLS certificate.
# Usage: bash pin_cert.sh your-vps.example.com [port]
# Output: Fingerprint string to paste into AgentWatch/Info.plist → VPSCertSHA256

set -euo pipefail

HOST="${1:?Usage: pin_cert.sh <hostname> [port]}"
PORT="${2:-443}"

echo "Fetching TLS certificate from ${HOST}:${PORT} ..."

FINGERPRINT=$(echo | openssl s_client -connect "${HOST}:${PORT}" -servername "${HOST}" 2>/dev/null \
  | openssl x509 -fingerprint -sha256 -noout \
  | sed 's/sha256 Fingerprint=//;s/://g' \
  | tr '[:upper:]' '[:lower:]')

echo ""
echo "SHA-256 Fingerprint (lowercase hex, no colons):"
echo "${FINGERPRINT}"
echo ""
echo "Add to AgentWatch/AgentWatch Watch App/Info.plist:"
echo "  <key>VPSCertSHA256</key>"
echo "  <string>${FINGERPRINT}</string>"
