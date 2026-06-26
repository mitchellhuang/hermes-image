FROM nousresearch/hermes-agent

# gh CLI (GitHub CLI) — installed via upstream apt repo per official docs.
# The Debian-community-packaged gh is broken on 2.45.x/2.46.x, so use the
# GitHub-maintained repo with the modern signed-by= keyring form.
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    out=$(mktemp) && \
    curl -fsSL -o "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    install -m 0755 "$out" /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod a+r "$out" && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/* && \
    gh --version

# kubectl — pinned to a stable version. Multi-arch aware via TARGETARCH
# (BuildKit auto-populates it).
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.36.2
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
ARG TARGETARCH
ARG OPENCODE_VERSION=v1.17.11
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
