# hermes-image

Custom hermes-agent image with `gh` (GitHub CLI), `kubectl`, and `opencode`
added on top of `nousresearch/hermes-agent:v2026.9.14`.

## Build

Push a `v*` tag to trigger a multi-arch (amd64 + arm64) build that publishes to
`ghcr.io/<owner>/hermes-image`.

```bash
git tag v0.1.0
git push origin v0.1.0
```

Manual build:

```bash
docker build -t hermes-image .
```

## Versions

| Tool | Version | Source |
|------|---------|--------|
| gh | 2.99.0 (apt repo) | https://cli.github.com/packages |
| kubectl | v1.36.4 | https://dl.k8s.io |
| opencode | v1.18.27 | https://github.com/anomalyco/opencode/releases |
| faster-whisper | 1.2.1 | PyPI |
