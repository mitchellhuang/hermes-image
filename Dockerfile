FROM mcr.microsoft.com/devcontainers/base:3.0.8-noble@sha256:d7c468679f45a52ad3673d06656b5bf16e488990b17216a1fa295d9e1f89d724

ARG TARGETARCH
ARG GH_VERSION=2.99.0
ARG KUBECTL_VERSION=v1.36.4
ARG OPENCODE_VERSION=2.0.20
ARG FLUX_VERSION=v2.9.5
ARG NODE_VERSION=24.21.0
ARG BUN_VERSION=1.4.2
ARG GO_VERSION=1.27.1
ARG UV_VERSION=0.12.21
ARG HELM_VERSION=4.3.0

USER root

# The devcontainer base already includes git, ssh, curl, jq, compilers, make,
# unzip, zip, procps, sudo, and zsh. Install only the additional system tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ripgrep fd-find cmake gdb python3 python3-pip python3-venv \
      pkg-config xz-utils tini shellcheck sqlite3 dnsutils netcat-openbsd lsof \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI from GitHub's pinned package, not Ubuntu's older package.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in amd64) gh_arch=amd64 ;; arm64) gh_arch=arm64 ;; *) exit 1 ;; esac; \
    curl -fsSL -o /tmp/gh.deb "https://cli.github.com/packages/pool/main/g/gh/gh_${GH_VERSION}_${gh_arch}.deb"; \
    apt-get update; apt-get install -y --no-install-recommends /tmp/gh.deb; \
    rm -f /tmp/gh.deb; rm -rf /var/lib/apt/lists/*; gh --version

# Pinned kubectl with upstream SHA256 verification.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in amd64|arm64) kubectl_arch=${TARGETARCH:-amd64} ;; *) exit 1 ;; esac; \
    url="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${kubectl_arch}/kubectl"; \
    curl -fsSL -o /tmp/kubectl "$url"; curl -fsSL -o /tmp/kubectl.sha256 "${url}.sha256"; \
    echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check -; \
    install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; rm /tmp/kubectl*; kubectl version --client=true --output=yaml

# OpenCode V2 native npm tarballs, pinned by SHA512 digest.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) oc_arch=x64; oc_sha512=0b8ee10035afd8c0fa3b3c0c867da2057710563bf00d3933a41ee42a52fc27ebc94312f3c2ce7cd2f7e0a5345807b248b451b5554b7a207aaa8b4d150a6acf46 ;; \
      arm64) oc_arch=arm64; oc_sha512=24b1c38043e64e16636d0108c193417702dd76fc58148b2c0da0db0dbfe717b6b0e03e71b7dc4651ad68ea7175216d4293ea71f24578eb95b602e4e1291537b2 ;; \
      *) exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/opencode.tgz "https://registry.npmjs.org/@opencode/cli-linux-${oc_arch}/-/cli-linux-${oc_arch}-${OPENCODE_VERSION}.tgz"; \
    echo "${oc_sha512}  /tmp/opencode.tgz" | sha512sum --check -; \
    tar -xzf /tmp/opencode.tgz -C /tmp package/bin/opencode; \
    install -m 0755 /tmp/package/bin/opencode /usr/local/bin/opencode; \
    rm -rf /tmp/package /tmp/opencode.tgz; opencode --version

# Flux release archive checked against its published SHA256 manifest.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in amd64|arm64) flux_arch=${TARGETARCH:-amd64} ;; *) exit 1 ;; esac; \
    flux_archive="flux_${FLUX_VERSION#v}_linux_${flux_arch}.tar.gz"; tmpdir=$(mktemp -d); \
    curl -fsSL -o "${tmpdir}/${flux_archive}" "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/${flux_archive}"; \
    curl -fsSL -o "${tmpdir}/checksums.txt" "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_checksums.txt"; \
    (cd "$tmpdir" && sha256sum --ignore-missing --check checksums.txt); \
    tar -xzf "${tmpdir}/${flux_archive}" -C "$tmpdir" flux; install -m 0755 "${tmpdir}/flux" /usr/local/bin/flux; \
    rm -rf "$tmpdir"; flux --version

# Node.js official binary distribution and SHASUMS256 manifest.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) exit 1 ;; esac; \
    node_file="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; node_url="https://nodejs.org/dist/v${NODE_VERSION}/${node_file}"; \
    curl -fsSL -o "/tmp/${node_file}" "$node_url"; curl -fsSL -o /tmp/node-shasums "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
    grep -E "^[[:xdigit:]]{64}  ${node_file}$" /tmp/node-shasums > /tmp/node-check; \
    (cd /tmp && sha256sum --check node-check); \
    tar -xJf "/tmp/${node_file}" -C /usr/local --strip-components=1; \
    rm -f "/tmp/${node_file}" /tmp/node-shasums; node --version; npm --version

# Bun portable x64 baseline / native arm64 archive; verify release checksums.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) bun_arch=x64-baseline; bun_member=bun-linux-x64-baseline ;; \
      arm64) bun_arch=aarch64; bun_member=bun-linux-aarch64 ;; \
      *) exit 1 ;; \
    esac; \
    bun_archive="bun-linux-${bun_arch}.zip"; bun_url="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${bun_archive}"; \
    curl -fsSL -o "/tmp/${bun_archive}" "$bun_url"; curl -fsSL -o /tmp/bun-shasums "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/SHASUMS256.txt"; \
    grep -E "^[[:xdigit:]]{64}  ${bun_archive}$" /tmp/bun-shasums > /tmp/bun-check; (cd /tmp && sha256sum --check bun-check); \
    unzip -q "/tmp/${bun_archive}" "${bun_member}/bun" -d /tmp; install -m 0755 "/tmp/${bun_member}/bun" /usr/local/bin/bun; \
    rm -rf "/tmp/${bun_archive}" /tmp/bun-shasums "/tmp/${bun_member}"; bun --version

# Go pinned tarballs with hard-pinned upstream checksums.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) go_arch=amd64; go_sha256=63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445 ;; \
      arm64) go_arch=arm64; go_sha256=3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec ;; \
      *) exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/go.tgz "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz"; \
    echo "${go_sha256}  /tmp/go.tgz" | sha256sum --check -; \
    tar -xzf /tmp/go.tgz -C /usr/local; rm /tmp/go.tgz

# uv and Helm release archives checked using their published SHA256 files.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in amd64) uv_arch=x86_64; helm_arch=amd64 ;; arm64) uv_arch=aarch64; helm_arch=arm64 ;; *) exit 1 ;; esac; \
    uv_archive="uv-${uv_arch}-unknown-linux-gnu.tar.gz"; uv_url="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${uv_archive}"; \
    curl -fsSL -o "/tmp/${uv_archive}" "$uv_url"; curl -fsSL -o /tmp/uv-sha256 "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/sha256.sum"; \
    grep -E "^[[:xdigit:]]{64} [* ]${uv_archive}$" /tmp/uv-sha256 > /tmp/uv-check; (cd /tmp && sha256sum --check uv-check); \
    tar -xzf "/tmp/${uv_archive}" -C /tmp; install -m 0755 "/tmp/uv-${uv_arch}-unknown-linux-gnu/uv" /usr/local/bin/uv; \
    helm_archive="helm-v${HELM_VERSION}-linux-${helm_arch}.tar.gz"; helm_url="https://get.helm.sh/${helm_archive}"; \
    curl -fsSL -o "/tmp/${helm_archive}" "$helm_url"; curl -fsSL "${helm_url}.sha256sum" -o /tmp/helm-sha256; \
    echo "$(awk '{print $1}' /tmp/helm-sha256)  /tmp/${helm_archive}" | sha256sum --check -; \
    tar -xzf "/tmp/${helm_archive}" -C /tmp "linux-${helm_arch}/helm"; install -m 0755 "/tmp/linux-${helm_arch}/helm" /usr/local/bin/helm; \
    rm -rf "/tmp/${uv_archive}" /tmp/uv-sha256 "/tmp/uv-${uv_arch}-unknown-linux-gnu" "/tmp/${helm_archive}" /tmp/helm-sha256 "/tmp/linux-${helm_arch}"; \
    uv --version; helm version --short

ENV PATH="/usr/local/go/bin:/home/vscode/.local/bin:/home/vscode/go/bin:${PATH}" \
    GOPATH=/home/vscode/go \
    GOBIN=/home/vscode/go/bin
RUN install -d /workspace /home/vscode/.cache /home/vscode/.local/bin /home/vscode/go/bin \
    && chown -R vscode:vscode /workspace /home/vscode
WORKDIR /workspace
USER vscode

COPY --chmod=0755 --chown=root:root image-smoke-test /usr/local/bin/image-smoke-test
RUN /usr/local/bin/image-smoke-test

EXPOSE 4096
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
