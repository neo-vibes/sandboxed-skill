#!/bin/bash
# Login to sandboxed.sh and get JWT token
# Usage: ./login.sh [password]
# Outputs token to stdout, can be captured: TOKEN=$(./login.sh)

set -e

API_URL="${SANDBOXED_API_URL:-http://localhost:8080}"
PASSWORD="${1:-${SANDBOXED_PASSWORD:?Set SANDBOXED_PASSWORD or pass as argument}}"

RESPONSE=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg pw "$PASSWORD" '{password: $pw}')")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  echo "Login failed: $RESPONSE" >&2
  exit 1
fi

echo "$TOKEN"
