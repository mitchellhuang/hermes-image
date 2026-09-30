# opencode-image

A multi-architecture (amd64 and arm64) OpenCode V2 development image based on
the pinned Ubuntu 24.04 devcontainers base. It runs as the non-root `vscode`
user (uid 1000), with `/workspace` as the working directory and OpenCode's
server listening on port 4096 by default.

The image contains no baked credentials or authentication configuration. Use
OpenCode V2's supported runtime authentication flow; do not assume V1 server
environment variables configure V2 authentication. In runtime smoke testing,
unauthenticated `GET /api/health` returned HTTP 401, so probes must account for
V2 authentication. OpenCode startup status is emitted unmodified on stdout; this
image does not provision credentials or redact runtime logs. Persist
`/home/vscode` for user configuration and caches, and mount project files at
`/workspace`.

## Build and run

Push a `v*` tag to build and publish to `ghcr.io/<owner>/opencode-image`.
The image build runs a tool and non-root filesystem smoke test before publish.

```sh
docker build -t opencode-image .
docker run --rm -p 4096:4096 -v "$PWD:/workspace" opencode-image
```

Override the default command by appending a command to `docker run`, for
example `docker run --rm opencode-image opencode --version`.

## Included tools

The pinned devcontainers base supplies Ubuntu 24.04, git, ssh, curl, jq, gcc,
g++, make, unzip, zip, procps, sudo, and zsh. This image adds:

| Tool | Version | Source |
|------|---------|--------|
| GitHub CLI (`gh`) | 2.99.0 | GitHub CLI package |
| kubectl | v1.36.4 | Kubernetes release (SHA256 verified) |
| OpenCode | V2 2.0.20 | Architecture-specific npm package (SHA512 verified) |
| Flux CLI | v2.9.5 | Flux release (SHA256 verified) |
| Node.js / npm | 24.21.0 | Node.js release (SHA256 verified) |
| Bun | 1.4.2 | Bun release (SHA256 verified) |
| Go | 1.27.1 | Go release (pinned SHA256) |
| uv | 0.12.21 | uv release (SHA256 verified) |
| Helm | 4.3.0 | Helm release (SHA256 verified) |
| Python | Ubuntu 24.04 package | `python3`, pip, and venv |
| Additional utilities | Ubuntu 24.04 packages | ripgrep, fd, cmake, gdb, shellcheck, sqlite3, dnsutils, netcat, lsof |
