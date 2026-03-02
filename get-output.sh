#!/bin/bash
# Get mission output (assistant messages)
# Usage: ./get-output.sh <mission_id> [limit]

set -e

MISSION_ID="${1:?Usage: $0 <mission_id> [limit]}"
LIMIT="${2:-50}"

API_URL="${SANDBOXED_API_URL:-http://localhost:8080}"
TOKEN="${SANDBOXED_API_TOKEN:?Set SANDBOXED_API_TOKEN}"

# Get events filtered to assistant messages
curl -s "$API_URL/api/control/missions/$MISSION_ID/events?types=assistant_message&limit=$LIMIT" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[] | .content // .metadata.content // empty'
