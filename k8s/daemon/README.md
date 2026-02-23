# Makima Daemon — Kubernetes Deployment

Run makima daemon workers in Kubernetes. Each daemon pod connects to the Makima server via WebSocket, authenticates with an API key, and executes tasks that involve git operations and Claude Code subprocesses.

## Prerequisites

- Kubernetes 1.25+
- `kubectl` configured for your cluster
- A Makima server accessible from inside the cluster
- A Makima API key (generate one from the Makima dashboard)
- *(Optional)* A GitHub personal access token for `gh` CLI operations
- *(Optional)* SSH keys for git-over-SSH authentication

## Quick Start

### 1. Build the daemon image

From the repository root:

```bash
docker build -f k8s/daemon/Dockerfile -t ghcr.io/soryu-co/makima-daemon:latest .
docker push ghcr.io/soryu-co/makima-daemon:latest
```

> **Note:** The daemon image is also published as `ghcr.io/soryu-co/makima:latest`.
> Both images are byte-identical; the shorter name is provided as a convenience.

### 2. Configure secrets

Edit `secret.yaml` with your actual credentials, or create the secret directly:

```bash
kubectl create secret generic makima-daemon-secrets \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=github-token=YOUR_GITHUB_TOKEN
```

### 3. Configure the server URL

Edit `configmap.yaml` to point to your Makima server:

```yaml
data:
  server-url: "wss://api.makima.jp"   # or your self-hosted server
  log-level: "makima=info"
```

### 4. Deploy with Kustomize

```bash
kubectl apply -k k8s/daemon/
```

Or apply individual manifests:

```bash
kubectl apply -f k8s/daemon/configmap.yaml
kubectl apply -f k8s/daemon/secret.yaml
kubectl apply -f k8s/daemon/deployment.yaml
kubectl apply -f k8s/daemon/hpa.yaml
```

### 5. Verify

```bash
kubectl get pods -l app=makima-daemon
kubectl logs -l app=makima-daemon -f
```

## Scaling

### Horizontal Pod Autoscaler

The included `hpa.yaml` scales the daemon deployment between 1 and 10 replicas based on:

| Metric | Target | Description |
|--------|--------|-------------|
| CPU | 70% utilization | Scales up when tasks are CPU-bound |
| Memory | 80% utilization | Scales up when worktrees consume memory |

Scale-up adds up to 2 pods per minute; scale-down removes 1 pod every 2 minutes with a 5-minute stabilization window to avoid flapping.

### Manual scaling

```bash
# Scale to 5 replicas
kubectl scale deployment makima-daemon --replicas=5

# Or patch the HPA limits
kubectl patch hpa makima-daemon -p '{"spec":{"maxReplicas":20}}'
```

## SSH Keys

To use SSH-based git authentication, create a secret with your SSH key:

```bash
kubectl create secret generic makima-daemon-ssh \
  --from-file=id_ed25519=$HOME/.ssh/id_ed25519 \
  --from-file=known_hosts=$HOME/.ssh/known_hosts
```

The deployment mounts this at `/root/.ssh` (read-only, mode 0600).

> **Tip:** For GitHub, you can use a deploy key or a personal SSH key. Make sure
> `github.com` is in your `known_hosts` file.

## Environment Variables

All daemon configuration can be controlled via environment variables. The deployment
sources these from the ConfigMap and Secret, but you can add more in the deployment spec.

| Variable | Source | Description |
|----------|--------|-------------|
| `MAKIMA_API_KEY` | Secret | **(Required)** API key for server authentication |
| `MAKIMA_DAEMON_SERVER_URL` | ConfigMap | WebSocket URL of the Makima server |
| `RUST_LOG` | ConfigMap | Log level filter (e.g., `makima=info`, `makima=debug`) |
| `GITHUB_TOKEN` | Secret | GitHub PAT for `gh` CLI and HTTPS git auth |
| `GH_TOKEN` | Secret | Alias for `GITHUB_TOKEN` (used by `gh` CLI) |
| `MAKIMA_DAEMON_WORKTREE_BASEDIR` | Dockerfile | Base dir for worktrees (default: `/app/workdir`) |
| `MAKIMA_DAEMON_WORKTREE_REPOSDIR` | Dockerfile | Cached repo clones (default: `/app/workdir/repos`) |
| `MAKIMA_DAEMON_LOCALDB_PATH` | Dockerfile | SQLite database path (default: `/app/data/daemon.db`) |
| `MAKIMA_DAEMON_PROCESS_MAXCONCURRENTTASKS` | — | Max concurrent tasks per daemon (default: 10) |
| `MAKIMA_DAEMON_PROCESS_CLAUDECOMMAND` | — | Path to Claude Code CLI (default: `claude`) |
| `MAKIMA_DAEMON_SERVER_HEARTBEATINTERVALSECS` | — | WebSocket heartbeat interval (default: 30) |
| `MAKIMA_DAEMON_SERVER_RECONNECTINTERVALSECS` | — | Reconnect delay on disconnect (default: 5) |

## Resource Tuning

Default resource requests/limits:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

**When to increase resources:**
- Tasks involve large repositories — increase `memory` limits and `workdir` volume size
- Many concurrent tasks per pod — increase `cpu` limits and `MAKIMA_DAEMON_PROCESS_MAXCONCURRENTTASKS`
- Large diffs or many worktrees — increase the `emptyDir.sizeLimit` on the `workdir` volume

## Troubleshooting

### Pod is CrashLoopBackOff

```bash
kubectl logs <pod-name> --previous
```

Common causes:
- **"API key is required"** — the `makima-daemon-secrets` secret is missing or `api-key` is empty
- **"Authentication failed"** — the API key is invalid or the server URL is wrong
- **DNS resolution failure** — the server URL hostname is not resolvable from inside the cluster

### Daemon connects but no tasks execute

- Verify the daemon appears in the Makima dashboard under connected daemons
- Check that `GITHUB_TOKEN` is set if tasks involve GitHub repositories
- Ensure the `claude` CLI is available inside the container (it should be, but custom images may differ)

### Worktree disk pressure

The `workdir` volume is an `emptyDir` with a 10Gi limit. If tasks create many large worktrees:

```bash
# Check disk usage inside a pod
kubectl exec <pod-name> -- du -sh /app/workdir/*
```

Increase the limit in `deployment.yaml` or switch to a PersistentVolumeClaim for larger workloads.

### Viewing daemon logs

```bash
# Follow logs from all daemon pods
kubectl logs -l app=makima-daemon -f --tail=100

# Debug-level logging
kubectl set env deployment/makima-daemon RUST_LOG=makima=debug
```
