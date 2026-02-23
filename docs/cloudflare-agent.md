# Makima Cloudflare Agent

Edge relay agent for [Makima](https://github.com/soryu-co/makima) — distributed task orchestration for AI coding agents.

This Cloudflare Worker acts as a **WebSocket relay** between the Makima server and native daemon instances. It runs on Cloudflare's edge network using Durable Objects for persistent state and connections.

## Why an Edge Relay?

The full Makima daemon requires native capabilities (process spawning, git operations, filesystem access) that aren't available on Cloudflare Workers. Instead, this agent serves as:

1. **WebSocket Relay** — Bridges the Makima server with remote daemon instances via persistent WebSocket connections
2. **Task Queue Manager** — Receives tasks from the server and dispatches them to the least-loaded downstream daemon
3. **Status Aggregator** — Tracks daemon health and task history across edge locations
4. **API Proxy** — Provides HTTP endpoints for monitoring and management from the edge

## Architecture

```
                         Cloudflare Edge
                    ┌─────────────────────────┐
                    │                         │
  Makima Server ◄──►│    MakimaAgent          │◄──► Native Daemon 1
  (wss://...)       │    (Durable Object)     │◄──► Native Daemon 2
                    │                         │◄──► Native Daemon N
                    │  ┌───────────────────┐  │
                    │  │ SQLite State      │  │
                    │  │ - Task history    │  │
                    │  │ - Connection logs │  │
                    │  └───────────────────┘  │
                    │                         │
                    └─────────────────────────┘
```

**Message flow:**

1. The agent maintains a persistent WebSocket to the Makima server (upstream)
2. Native daemons connect to the agent via WebSocket at `/ws/daemon` (downstream)
3. When the server sends a `SpawnTask` command, the agent selects the least-loaded downstream daemon and forwards the task
4. Task output, progress, and completion messages from daemons are relayed back to the server
5. The agent sends periodic heartbeats and tracks all task dispatches in SQLite

## Prerequisites

- **Cloudflare Account** with Workers and Durable Objects enabled
- **Node.js 18+** and npm
- **Makima Server** running and accessible (default: `wss://api.makima.jp`)
- **API Key** from your Makima server dashboard

## Quick Setup

```bash
# Clone and navigate to the cloudflare-agent directory
cd makima/cloudflare-agent

# Run the interactive setup script
chmod +x setup.sh
./setup.sh
```

The setup script will:

1. Check prerequisites (Node.js 18+, npm, npx)
2. Prompt for your Makima server URL and API key
3. Install npm dependencies
4. Create `.dev.vars` with your secrets
5. Check Cloudflare authentication (offer to log in)
6. Optionally set production secrets
7. Offer to deploy immediately or start a dev server

## Manual Setup

If you prefer manual configuration:

```bash
# 1. Install dependencies
npm install

# 2. Create local secrets file
cat > .dev.vars <<EOF
MAKIMA_SERVER_URL=wss://api.makima.jp
MAKIMA_API_KEY=your-api-key-here
MAKIMA_AGENT_NAME=my-edge-agent
EOF

# 3. Log in to Cloudflare
npx wrangler login

# 4. Set production secrets
echo "wss://api.makima.jp" | npx wrangler secret put MAKIMA_SERVER_URL
echo "your-api-key-here"   | npx wrangler secret put MAKIMA_API_KEY
echo "my-edge-agent"       | npx wrangler secret put MAKIMA_AGENT_NAME

# 5. Deploy
npx wrangler deploy
```

## Development

```bash
# Start local dev server with hot reload
npm run dev

# Stream production logs
npm run tail

# Deploy to Cloudflare
npm run deploy
```

## API Endpoints

After deployment, the agent exposes these HTTP endpoints:

| Method | Path          | Description                              |
|--------|---------------|------------------------------------------|
| GET    | `/`           | Agent status (same as `/status`)         |
| GET    | `/status`     | Connection status and daemon overview    |
| GET    | `/health`     | Simple health check                      |
| GET    | `/tasks`      | Task dispatch history (paginated)        |
| GET    | `/logs`       | Connection event logs                    |
| POST   | `/reconnect`  | Force reconnection to upstream server    |
| WS     | `/ws/daemon`  | WebSocket endpoint for downstream daemons|

### Query Parameters

- **`/tasks`**: `?limit=50&offset=0` — Paginate task history
- **`/logs`**: `?limit=50` — Limit log entries returned

### Example Responses

**GET /status**
```json
{
  "status": "ok",
  "agentName": "makima-edge",
  "upstreamConnected": true,
  "daemonId": "550e8400-e29b-41d4-a716-446655440000",
  "lastHeartbeat": "2024-12-15T10:30:00.000Z",
  "connectedDaemons": 2,
  "activeTasks": 3,
  "totalTasksProcessed": 142
}
```

**GET /health**
```json
{
  "healthy": true,
  "upstreamConnected": true
}
```

## Environment Variables

| Variable              | Required | Description                                    | Default               |
|-----------------------|----------|------------------------------------------------|-----------------------|
| `MAKIMA_SERVER_URL`   | Yes      | WebSocket URL of the Makima server             | —                     |
| `MAKIMA_API_KEY`      | Yes      | API key for server authentication              | —                     |
| `MAKIMA_AGENT_NAME`   | No       | Human-readable name for this agent             | `makima-edge-{id}`    |

Set these as Cloudflare Workers secrets for production:
```bash
echo "value" | npx wrangler secret put VARIABLE_NAME
```

For local development, put them in `.dev.vars` (gitignored automatically).

## How It Works

### Upstream Connection (to Makima Server)

1. On startup, the agent opens a WebSocket to `MAKIMA_SERVER_URL/ws/daemon`
2. It authenticates using the `MAKIMA_API_KEY` with `maxConcurrentTasks: 0` (relay-only mode)
3. Sends heartbeats every 30 seconds
4. On disconnect, reconnects with exponential backoff (1s → 60s, max 20 attempts)

### Downstream Connections (from Native Daemons)

1. Native Makima daemons connect via WebSocket to `/ws/daemon`
2. Daemons authenticate with their hostname and max concurrent task count
3. The agent tracks each daemon's active tasks and health

### Task Dispatch

When the server sends a `SpawnTask` command:
1. The agent records the task in SQLite
2. Selects the downstream daemon with the fewest active tasks (that still has capacity)
3. Forwards the full `SpawnTask` command
4. If no daemons are available, the task remains pending

### Persistence

The agent uses Cloudflare Durable Objects with SQLite for:
- **Task history** — All received, dispatched, completed, and failed tasks
- **Connection logs** — Connect/disconnect/error events (last 200 entries)
- **Agent state** — Connection status, daemon ID, active tasks

The Durable Object auto-hibernates when idle and resumes on the next request, preserving all state.

## Connecting Native Daemons

Native Makima daemons can connect to this edge relay instead of directly to the server. Configure the daemon to point at your deployed Worker URL:

```toml
# makima-daemon.toml
[server]
url = "wss://makima-agent.your-account.workers.dev/ws/daemon"
api_key = "your-api-key"
```

Or via environment variable:
```bash
MAKIMA_DAEMON_SERVER__URL=wss://makima-agent.your-account.workers.dev/ws/daemon \
MAKIMA_DAEMON_SERVER__API_KEY=your-api-key \
makima daemon
```

## Troubleshooting

### Agent shows "disconnected" status
- Verify `MAKIMA_SERVER_URL` is correct and the server is reachable
- Check that `MAKIMA_API_KEY` is valid
- Review connection logs at `GET /logs`

### Tasks stuck in "pending"
- No downstream daemons are connected
- Ensure native daemons are pointing to this agent's `/ws/daemon` endpoint
- Check `GET /status` for `connectedDaemons` count

### Deployment fails
- Ensure you're logged in: `npx wrangler whoami`
- Ensure your account has Durable Objects enabled
- Check `wrangler.toml` configuration

## License

Part of the [Makima](https://github.com/soryu-co/makima) project.
