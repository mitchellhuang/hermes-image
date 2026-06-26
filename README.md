# hermes-image

Custom hermes-agent image with `gh` (GitHub CLI), `kubectl`, and `opencode`
added on top of `nousresearch/hermes-agent`.

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
| gh | latest (apt repo) | https://cli.github.com/packages |
| kubectl | v1.36.2 | https://dl.k8s.io |
| opencode | v1.17.11 | https://github.com/anomalyco/opencode/releases |
