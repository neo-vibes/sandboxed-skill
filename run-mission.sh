#!/bin/bash
# Run a sandboxed.sh mission end-to-end
# Usage: ./run-mission.sh "Task prompt" [backend] [workspace_id]

set -e

PROMPT="${1:?Usage: $0 \"Task prompt\" [backend] [workspace_id]}"
BACKEND="${2:-claudecode}"
WORKSPACE_ID="${3:-}"

API_URL="${SANDBOXED_API_URL:-http://localhost:8080}"
TOKEN="${SANDBOXED_API_TOKEN:?Set SANDBOXED_API_TOKEN}"

# Create mission
echo "Creating mission..."
MISSION=$(curl -s -X POST "$API_URL/api/control/missions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "$PROMPT" \
    --arg backend "$BACKEND" \
    --arg ws "$WORKSPACE_ID" \
    '{title: $title, backend: $backend} + (if $ws != "" then {workspace_id: $ws} else {} end)'
  )")

MISSION_ID=$(echo "$MISSION" | jq -r '.id')
echo "Mission created: $MISSION_ID"

# Load mission
echo "Loading mission..."
curl -s -X POST "$API_URL/api/control/missions/$MISSION_ID/load" \
  -H "Authorization: Bearer $TOKEN" > /dev/null

# Send prompt
echo "Sending prompt..."
curl -s -X POST "$API_URL/api/control/message" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg content "$PROMPT" '{content: $content}')" > /dev/null

echo "Mission running: $MISSION_ID"
echo ""
echo "Poll status with:"
echo "  curl \"$API_URL/api/control/missions/$MISSION_ID\" -H \"Authorization: Bearer \$SANDBOXED_API_TOKEN\""
echo ""
echo "Stream events with:"
echo "  curl -N \"$API_URL/api/control/stream\" -H \"Authorization: Bearer \$SANDBOXED_API_TOKEN\""

# Return mission ID for scripting
echo "$MISSION_ID"
