FROM nousresearch/hermes-agent:v2026.9.14

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

# 1Password CLI — pin the version and use 1Password's signed Debian
# repository. The desktop application is intentionally not installed.
ARG OP_VERSION=2.39.0-1
RUN set -eux; \
    op_arch=$(dpkg --print-architecture); \
    case "${op_arch}" in \
      amd64|arm64) ;; \
      *) echo "unsupported dpkg architecture=${op_arch}" >&2; exit 1 ;; \
    esac; \
    apt-get update; \
    apt-get install -y --no-install-recommends debsig-verify gnupg; \
    mkdir -p -m 0755 /etc/apt/keyrings \
      /etc/debsig/policies/AC2D62742012EA22 \
      /usr/share/debsig/keyrings/AC2D62742012EA22; \
    curl -fsSL -o /tmp/1password.asc \
      https://downloads.1password.com/linux/keys/1password.asc; \
    gpg --batch --with-colons --import-options show-only --import /tmp/1password.asc \
      > /tmp/1password-key-info; \
    test "$(awk -F: '$1 == "fpr" { print $10; exit }' /tmp/1password-key-info)" = \
      3FEF9748469ADBE15DA7CA80AC2D62742012EA22; \
    gpg --batch --dearmor --yes --output /etc/apt/keyrings/1password-archive-keyring.gpg \
      /tmp/1password.asc; \
    gpg --batch --dearmor --yes --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg \
      /tmp/1password.asc; \
    curl -fsSL -o /etc/debsig/policies/AC2D62742012EA22/1password.pol \
      https://downloads.1password.com/linux/debian/debsig/1password.pol; \
    printf '%s\n' \
      "deb [arch=${op_arch} signed-by=/etc/apt/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/${op_arch} stable main" \
      > /etc/apt/sources.list.d/1password.list; \
    apt-get update; \
    cd /tmp; \
    apt-get download "1password-cli=${OP_VERSION}"; \
    debsig-verify "/tmp/1password-cli-${OP_VERSION}.${op_arch}.deb"; \
    apt-get install -y --no-install-recommends "/tmp/1password-cli-${OP_VERSION}.${op_arch}.deb"; \
    rm -f /tmp/1password.asc /tmp/1password-key-info \
      "/tmp/1password-cli-${OP_VERSION}.${op_arch}.deb"; \
    rm -rf /var/lib/apt/lists/*; \
    op --version

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

# opencode CLI — pinned, multi-arch via direct tarball from GitHub releases.
# Avoids curl|sh; matches the kubectl install pattern. The tarball contains a
# single `opencode` binary at the root.
ARG OPENCODE_VERSION=v1.18.27
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) oc_arch=x64 ;; \
      arm64) oc_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1; \
    esac; \
    curl -fsSL -o /tmp/opencode.tar.gz \
      "https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/opencode-linux-${oc_arch}.tar.gz" && \
    tar -xzf /tmp/opencode.tar.gz -C /tmp && \
    install -m 0755 /tmp/opencode /usr/local/bin/opencode && \
    rm -rf /tmp/opencode /tmp/opencode.tar.gz && \
    opencode --version

# faster-whisper — local STT backend for voice message transcription via Hermes.
# --break-system-packages bypasses PEP 668's externally-managed guard on the
# base image's system Python (3.13); --system installs into that interpreter
# rather than a venv so the hermes-agent runtime can import it directly.
RUN uv pip install --system --break-system-packages faster-whisper==1.2.1
