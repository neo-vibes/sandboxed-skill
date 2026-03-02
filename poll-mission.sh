#!/bin/bash
# Poll a sandboxed.sh mission until completion
# Usage: ./poll-mission.sh <mission_id> [interval_seconds]

set -e

MISSION_ID="${1:?Usage: $0 <mission_id> [interval_seconds]}"
INTERVAL="${2:-15}"

API_URL="${SANDBOXED_API_URL:-http://localhost:8080}"
TOKEN="${SANDBOXED_API_TOKEN:?Set SANDBOXED_API_TOKEN}"

echo "Polling mission $MISSION_ID every ${INTERVAL}s..."

while true; do
  RESPONSE=$(curl -s "$API_URL/api/control/missions/$MISSION_ID" \
    -H "Authorization: Bearer $TOKEN")
  
  STATUS=$(echo "$RESPONSE" | jq -r '.status')
  TITLE=$(echo "$RESPONSE" | jq -r '.title // "Untitled"')
  
  echo "[$(date +%H:%M:%S)] Status: $STATUS - $TITLE"
  
  case "$STATUS" in
    completed)
      echo "✅ Mission completed"
      exit 0
      ;;
    failed)
      echo "❌ Mission failed"
      exit 1
      ;;
    interrupted)
      echo "⚠️  Mission interrupted"
      exit 2
      ;;
    pending|active)
      sleep "$INTERVAL"
      ;;
    *)
      echo "Unknown status: $STATUS"
      exit 3
      ;;
  esac
done
