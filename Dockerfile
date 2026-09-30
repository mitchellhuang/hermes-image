FROM nousresearch/hermes-agent:v2026.9.24

# gh CLI (GitHub CLI) — installed from the versioned package in the upstream
# apt repository. The Debian-community-packaged gh is broken on 2.45.x/2.46.x,
# so use the GitHub-maintained repo with the modern signed-by= keyring form.
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    out=$(mktemp) && \
    curl -fsSL -o "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    install -m 0755 "$out" /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod a+r "$out" && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    gh_arch=$(dpkg --print-architecture) && \
    curl -fsSL -o /tmp/gh.deb \
      "https://cli.github.com/packages/pool/main/g/gh/gh_2.99.0_${gh_arch}.deb" && \
    apt-get install -y --no-install-recommends /tmp/gh.deb && \
    rm -f /tmp/gh.deb && \
    rm -rf /var/lib/apt/lists/* && \
    gh --version

# kubectl — pinned to a stable version. Multi-arch aware via TARGETARCH
# (BuildKit auto-populates it).
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.36.4
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) kubectl_arch=amd64 ;; \
      arm64) kubectl_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${kubectl_arch}/kubectl" && \
    chmod 0755 /usr/local/bin/kubectl && \
    kubectl version --client=true --output=yaml

# opencode CLI V2 — pinned, multi-arch via the official npm native tarball.
# The tarball contains the binary at package/bin/opencode.
ARG OPENCODE_VERSION=2.0.20
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) oc_arch=x64 ;; \
      arm64) oc_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1; \
    esac; \
    curl -fsSL -o /tmp/opencode.tar.gz \
      "https://registry.npmjs.org/@opencode/cli-linux-${oc_arch}/-/cli-linux-${oc_arch}-${OPENCODE_VERSION}.tgz" && \
    tar -xzf /tmp/opencode.tar.gz -C /tmp package/bin/opencode && \
    install -m 0755 /tmp/package/bin/opencode /usr/local/bin/opencode && \
    rm -rf /tmp/package /tmp/opencode.tar.gz && \
    opencode --version

# Flux CLI — pinned, multi-arch via official GitHub release archives. Verify
# the downloaded archive against the release's official SHA256 checksums.
ARG FLUX_VERSION=v2.9.5
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) flux_arch=amd64 ;; \
      arm64) flux_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1; \
    esac; \
    flux_archive="flux_${FLUX_VERSION#v}_linux_${flux_arch}.tar.gz"; \
    tmpdir=$(mktemp -d); \
    curl -fsSL -o "${tmpdir}/${flux_archive}" \
      "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/${flux_archive}"; \
    curl -fsSL -o "${tmpdir}/flux_checksums.txt" \
      "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_checksums.txt"; \
    (cd "${tmpdir}" && sha256sum --ignore-missing --check flux_checksums.txt); \
    tar -xzf "${tmpdir}/${flux_archive}" -C "${tmpdir}" flux; \
    install -m 0755 "${tmpdir}/flux" /usr/local/bin/flux; \
    rm -rf "${tmpdir}"; \
    flux --version

# faster-whisper — local STT backend for voice message transcription via Hermes.
# --break-system-packages bypasses PEP 668's externally-managed guard on the
# base image's system Python (3.13); --system installs into that interpreter
# rather than a venv so the hermes-agent runtime can import it directly.
RUN uv pip install --system --break-system-packages faster-whisper==1.2.1
