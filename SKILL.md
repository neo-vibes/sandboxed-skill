# sandboxed.sh Skill

Self-hosted cloud orchestrator for AI coding agents. Create isolated missions on VPS for sandboxed code execution.

## When to Use

Use this skill when:
- User requests "sandboxed mode" for a task
- Running untrusted or high-risk code changes
- Need production-like isolation (systemd-nspawn containers)
- Multi-day unattended operations

## Quick Start (Workspace-as-Code)

Projects define their sandbox needs in `.sandboxed/`:

```
project/
├── .sandboxed/
│   ├── workspace.json    # Config (committed)
│   ├── .env              # Secrets (gitignored)
│   └── .env.example      # Template (committed)
└── ...
```

### workspace.json

```json
{
  "extends": "ubuntu",
  "repo": {
    "url": "github.com/org/repo",
    "branch": "main"
  },
  "secrets": ["GITHUB_TOKEN", "ANTHROPIC_API_KEY"],
  "init_commands": ["npm install"]
}
```

### .sandboxed/.env

```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxx
SANDBOXED_PASSWORD=your-dashboard-password
```

### Setup & Run

```bash
# Setup workspace from project config
./setup-project.sh /path/to/project

# Run a mission
./run-mission.sh "Implement feature X" claudecode $WORKSPACE_ID
```

## Setup

**VPS:** `142.132.205.30`
**Access:** SSH tunnel or Tailscale
**API Port:** 3000 (proxied via Caddy on 8080)

### SSH Tunnel (if needed)
```bash
ssh -L 8080:127.0.0.1:8080 yann@142.132.205.30
```

### Authentication

sandboxed.sh uses JWT auth. Get a token by logging in:

```bash
# Login and get JWT (valid ~30 days)
curl -s -X POST "http://localhost:8080/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"password": "YOUR_DASHBOARD_PASSWORD"}' | jq -r '.token'
```

Or use the helper:
```bash
export SANDBOXED_PASSWORD="your-dashboard-password"
export SANDBOXED_API_TOKEN=$(./login.sh)
```

### Environment Variables
```bash
export SANDBOXED_API_URL="http://localhost:8080"  # via tunnel
export SANDBOXED_PASSWORD="your-dashboard-password"
export SANDBOXED_API_TOKEN="eyJ..."  # JWT from login
```

Or for direct access (if Tailscale):
```bash
export SANDBOXED_API_URL="http://142.132.205.30:3000"
```

## API Reference

All endpoints require: `Authorization: Bearer $SANDBOXED_API_TOKEN`

### Create Mission

```bash
curl -X POST "$SANDBOXED_API_URL/api/control/missions" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Task description",
    "workspace_id": "uuid",
    "backend": "claudecode"
  }'
```

**Backend options:** `claudecode`, `opencode`, `amp`

**Response:**
```json
{
  "id": "mission-uuid",
  "status": "pending",
  "title": "Task description",
  "backend": "claudecode",
  "created_at": "2025-01-13T10:00:00Z"
}
```

### Load Mission (activate it)

```bash
curl -X POST "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID/load" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

### Send Message to Agent

```bash
curl -X POST "$SANDBOXED_API_URL/api/control/message" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "Your task prompt here"}'
```

**Response:**
```json
{"id": "message-uuid", "queued": false}
```

### Get Mission Status

```bash
curl "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

**Statuses:** `pending`, `active`, `completed`, `failed`, `interrupted`

### Get Mission Events (history)

```bash
curl "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID/events?limit=50" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

### Stream Events (SSE)

```bash
curl -N "$SANDBOXED_API_URL/api/control/stream" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

**Event types:** `status`, `user_message`, `assistant_message`, `thinking`, `tool_call`, `tool_result`, `error`, `mission_status_changed`

### Cancel Mission

```bash
curl -X POST "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID/cancel" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

### Set Mission Status

```bash
curl -X POST "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID/status" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'
```

### List Missions

```bash
curl "$SANDBOXED_API_URL/api/control/missions" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

### Delete Mission

```bash
curl -X DELETE "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"
```

## Orchestration Flow

As OpenClaw orchestrator, use this pattern:

```
1. Create mission (POST /api/control/missions)
   → Get mission_id

2. Load mission (POST /api/control/missions/:id/load)
   → Activates the mission

3. Send task prompt (POST /api/control/message)
   → Agent starts working

4. Poll status (GET /api/control/missions/:id)
   → Check until status = completed/failed
   
   OR stream events (GET /api/control/stream)
   → Real-time updates via SSE

5. Get results (GET /api/control/missions/:id/events)
   → Fetch agent output

6. Mark done (POST /api/control/missions/:id/status)
   → Set to "completed"
```

## Workspaces

Missions run in isolated workspaces. To use an existing workspace:

```bash
# List workspaces
curl "$SANDBOXED_API_URL/api/workspaces" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN"

# Create workspace
curl -X POST "$SANDBOXED_API_URL/api/workspaces" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-project", "git_url": "git@github.com:user/repo.git"}'
```

## Automations

Set up recurring tasks or webhook triggers:

```bash
curl -X POST "$SANDBOXED_API_URL/api/control/missions/$MISSION_ID/automations" \
  -H "Authorization: Bearer $SANDBOXED_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "command_source": {"inline": {"command": "echo check"}},
    "trigger": {"interval": {"seconds": 300}}
  }'
```

**Trigger types:**
- `{"interval": {"seconds": N}}` — Run every N seconds
- `{"webhook": {"config": {}}}` — HTTP webhook trigger
- `"agent_finished"` — After each agent turn

## Helper Scripts

All scripts are in `~/.openclaw/skills/sandboxed-sh/`

### Setup workspace from project config

```bash
# Reads .sandboxed/workspace.json and .sandboxed/.env
# Creates container workspace, clones repo, runs init commands
./setup-project.sh /path/to/project [workspace_name]
```

### Create and run a mission

```bash
./run-mission.sh "Build feature X" "claudecode" "workspace-uuid"
```

### Poll until complete

```bash
./poll-mission.sh $MISSION_ID
```

### Get mission output

```bash
./get-output.sh $MISSION_ID
```

### List workspaces

```bash
./list-workspaces.sh
```

## Error Handling

- `401` — Invalid or missing token
- `404` — Mission/workspace not found
- `409` — Mission already active (need to load it first)
- `queued: true` — Another message is processing, wait and retry

## Tips

1. **One mission = one task** — Keep missions focused
2. **Git integration** — Workspace should have git configured; agent commits are the output
3. **Polling interval** — Check status every 10-30s, not faster
4. **Timeouts** — Set reasonable timeouts; missions can run hours
5. **Logs** — Use events endpoint for debugging if something fails
