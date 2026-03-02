#!/bin/bash
# Setup a sandboxed workspace from a project's .sandboxed/ config
# Usage: ./setup-project.sh /path/to/project [workspace_name]

set -e

PROJECT_DIR="${1:?Usage: $0 /path/to/project [workspace_name]}"
WORKSPACE_NAME="${2:-$(basename "$PROJECT_DIR")}"

CONFIG_DIR="$PROJECT_DIR/.sandboxed"
CONFIG_FILE="$CONFIG_DIR/workspace.json"
ENV_FILE="$CONFIG_DIR/.env"

# Validate project structure
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found" >&2
  exit 1
fi

# Source secrets if .env exists
if [ -f "$ENV_FILE" ]; then
  echo "Loading secrets from $ENV_FILE"
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "Warning: $ENV_FILE not found, secrets may be missing" >&2
fi

# API setup
API_URL="${SANDBOXED_API_URL:-http://localhost:8080}"

# Login if no token
if [ -z "$SANDBOXED_API_TOKEN" ]; then
  if [ -z "$SANDBOXED_PASSWORD" ]; then
    echo "Error: Set SANDBOXED_API_TOKEN or SANDBOXED_PASSWORD" >&2
    exit 1
  fi
  echo "Logging in to sandboxed.sh..."
  SANDBOXED_API_TOKEN=$(curl -s -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$SANDBOXED_PASSWORD\"}" | jq -r '.token')
  export SANDBOXED_API_TOKEN
fi

# Read config
TEMPLATE=$(jq -r '.extends // "ubuntu"' "$CONFIG_FILE")
REPO_URL=$(jq -r '.repo.url // empty' "$CONFIG_FILE")
REPO_BRANCH=$(jq -r '.repo.branch // "main"' "$CONFIG_FILE")

echo "Project: $WORKSPACE_NAME"
echo "Template: $TEMPLATE"
echo "Repo: $REPO_URL ($REPO_BRANCH)"

# Create workspace
echo ""
echo "Creating workspace..."
WORKSPACE=$(curl -s -X POST "$API_URL/api/workspaces" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg name "$WORKSPACE_NAME" \
    --arg template "$TEMPLATE" \
    '{name: $name, template: $template}'
  )")

WORKSPACE_ID=$(echo "$WORKSPACE" | jq -r '.id')
STATUS=$(echo "$WORKSPACE" | jq -r '.status')

if [ "$WORKSPACE_ID" = "null" ] || [ -z "$WORKSPACE_ID" ]; then
  echo "Error creating workspace:" >&2
  echo "$WORKSPACE" | jq '.' >&2
  exit 1
fi

echo "Workspace ID: $WORKSPACE_ID"
echo "Status: $STATUS"

# Wait for build if building
if [ "$STATUS" = "building" ]; then
  echo ""
  echo "Building container (this may take a few minutes)..."
  while true; do
    sleep 10
    STATUS=$(curl -s "$API_URL/api/workspaces/$WORKSPACE_ID" \
      -H "Authorization: Bearer $SANDBOXED_API_TOKEN" | jq -r '.status')
    echo "  Status: $STATUS"
    
    if [ "$STATUS" = "ready" ]; then
      echo "Container ready!"
      break
    elif [ "$STATUS" = "error" ]; then
      echo "Build failed!" >&2
      curl -s "$API_URL/api/workspaces/$WORKSPACE_ID" \
        -H "Authorization: Bearer $SANDBOXED_API_TOKEN" | jq '.error_message' >&2
      exit 1
    fi
  done
fi

# Clone repo if configured
if [ -n "$REPO_URL" ]; then
  echo ""
  echo "Cloning repository..."
  
  # Build clone URL with token if available
  if [ -n "$GITHUB_TOKEN" ]; then
    CLONE_URL="https://x-access-token:${GITHUB_TOKEN}@${REPO_URL}"
  else
    CLONE_URL="https://${REPO_URL}"
  fi
  
  CLONE_RESULT=$(curl -s -X POST "$API_URL/api/workspaces/$WORKSPACE_ID/exec" \
    -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg cmd "cd /root && git clone -b $REPO_BRANCH $CLONE_URL project" \
      '{command: $cmd, timeout_secs: 120}'
    )")
  
  EXIT_CODE=$(echo "$CLONE_RESULT" | jq -r '.exit_code')
  if [ "$EXIT_CODE" != "0" ]; then
    echo "Clone failed:" >&2
    echo "$CLONE_RESULT" | jq -r '.stderr // .stdout' >&2
    exit 1
  fi
  echo "Repository cloned to /root/project"
fi

# Run init commands if configured
INIT_COMMANDS=$(jq -r '.init_commands // [] | .[]' "$CONFIG_FILE")
if [ -n "$INIT_COMMANDS" ]; then
  echo ""
  echo "Running init commands..."
  echo "$INIT_COMMANDS" | while read -r cmd; do
    echo "  > $cmd"
    curl -s -X POST "$API_URL/api/workspaces/$WORKSPACE_ID/exec" \
      -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(jq -n \
        --arg cmd "cd /root/project && $cmd" \
        '{command: $cmd, timeout_secs: 300}'
      )" | jq -r 'if .exit_code == 0 then "    OK" else "    FAILED: " + (.stderr // .stdout) end'
  done
fi

echo ""
echo "========================================="
echo "Workspace ready: $WORKSPACE_ID"
echo ""
echo "Run a mission:"
echo "  ./run-mission.sh \"Your task\" claudecode $WORKSPACE_ID"
echo ""
echo "Or export for other scripts:"
echo "  export WORKSPACE_ID=$WORKSPACE_ID"
