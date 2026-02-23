# makima

Makima is listening

[![](https://files.catbox.moe/hv4r24.png)](http://makima.jp)

---

Distributed task orchestration for AI coding daemons.

Makima coordinates work across multiple AI coding daemons, enabling parallel task execution, contract-based workflows, and seamless integration with tools like Claude Code.

## Installation

### Quick Install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/soryu-co/makima/master/install.sh | bash
```

The install script auto-detects your platform and downloads the latest release.

### Manual Download

Download the latest release for your platform from the [Releases page](https://github.com/soryu-co/makima/releases).

### Supported Platforms

| Platform          | Architecture |
|-------------------|-------------|
| Linux             | x86_64      |
| Linux             | ARM64       |
| macOS             | x86_64      |
| macOS             | ARM64 (Apple Silicon) |

After downloading, extract and install:

```bash
tar xzf makima-*.tar.gz
chmod +x makima
sudo mv makima /usr/local/bin/
```

### Verify Installation

```bash
makima --version
```

## Kubernetes Deployment

Makima can run as a daemon in Kubernetes for persistent task execution. Manifests are provided in [`k8s/daemon/`](k8s/daemon/).

The daemon container image is available at:

```
ghcr.io/soryu-co/makima:latest
```

Apply the manifests with kustomize:

```bash
kubectl apply -k k8s/daemon/
```

See [`k8s/daemon/README.md`](k8s/daemon/README.md) for full deployment instructions.

## Documentation

- [Cloudflare Edge Daemon](docs/cloudflare-agent.md) — Deploy a WebSocket relay on Cloudflare Workers for edge-based task dispatch

## License & Info

Makima is developed by [soryu-co](https://github.com/soryu-co). For more information, visit [makima.jp](http://makima.jp).
