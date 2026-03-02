#!/bin/bash
# List available workspaces
# Usage: ./list-workspaces.sh

set -e

API_URL="${SANDBOXED_API_URL:-http://localhost:8080}"
TOKEN="${SANDBOXED_API_TOKEN:?Set SANDBOXED_API_TOKEN}"

curl -s "$API_URL/api/workspaces" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[] | "\(.id)\t\(.name)\t\(.git_url // "no-git")"'
