# ==============================================================================
# Makima Daemon - Lightweight Container Image
# ==============================================================================
# This Dockerfile builds a minimal image for running `makima daemon` in
# Kubernetes. Unlike the full server image (which includes ML models), this
# image contains only the makima binary and the tools it needs to execute
# tasks: git, gh CLI, curl, and SSH client.
# ==============================================================================

# ---------- Builder stage ----------
FROM rust:1.91-bookworm AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy workspace files
COPY Cargo.toml Cargo.lock ./
COPY makima ./makima
COPY vendor ./vendor
COPY tools/stt-client ./tools/stt-client

# Build release binary
RUN cargo build --release --package makima --bin makima

# ---------- Runtime stage ----------
FROM debian:bookworm-slim

# Install runtime dependencies:
#   - ca-certificates: TLS certificate verification
#   - libssl3: OpenSSL runtime for TLS connections
#   - git: Git operations (clone, worktree, push, etc.)
#   - curl: Health checks and HTTP requests
#   - openssh-client: SSH key-based git authentication
#   - jq: JSON processing in scripts
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    git \
    curl \
    openssh-client \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary from the builder stage
COPY --from=builder /app/target/release/makima /usr/local/bin/makima

# Create application directories
#   - /app/workdir: Working directory for git worktrees
#   - /app/data: Local database and state
RUN mkdir -p /app/workdir /app/data /root/.makima

# Set environment defaults
ENV RUST_LOG=makima=info
ENV MAKIMA_DAEMON_WORKTREE_BASEDIR=/app/workdir
ENV MAKIMA_DAEMON_WORKTREE_REPOSDIR=/app/workdir/repos
ENV MAKIMA_DAEMON_LOCALDB_PATH=/app/data/daemon.db
ENV MAKIMA_DAEMON_REPOS_HOMEDIR=/app/workdir/home
ENV HOME=/root

WORKDIR /app

ENTRYPOINT ["makima"]
CMD ["daemon"]
