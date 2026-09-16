# syntax=docker/dockerfile:1.7
#
# GitHub Actions self-hosted runner image built on the OFFICIAL
# actions/runner release tarball (no third-party runner images).
#
# Build:
#   docker build -t github-runner:local \
#     --build-arg RUNNER_VERSION=2.337.0 \
#     -f docker/Dockerfile .
#
FROM ubuntu:24.04

ARG RUNNER_VERSION=2.337.0
# Leave empty to auto-detect from the build platform (recommended, and
# required for multi-arch `docker buildx build --platform ...` builds).
# Set explicitly ("x64" or "arm64") only to force a specific tarball.
ARG RUNNER_ARCH=""
# Automatically provided by BuildKit/buildx for the target platform.
ARG TARGETARCH
# Set to "true" to install the Docker CLI so the runner can talk to a
# Docker socket mounted from the host (see "Docker inside workflows" docs).
ARG INSTALL_DOCKER_CLI=false

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_VERSION=${RUNNER_VERSION} \
    RUNNER_HOME=/home/runner/actions-runner \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# --- Base packages -----------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        libicu74 \
        sudo \
        tar \
        tzdata \
        gnupg \
        lsb-release \
        unzip \
        && \
    rm -rf /var/lib/apt/lists/*

# --- Optional Docker CLI (client only, uses the host's mounted socket) --
RUN if [ "$INSTALL_DOCKER_CLI" = "true" ]; then \
        install -m 0755 -d /etc/apt/keyrings && \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
        chmod a+r /etc/apt/keyrings/docker.asc && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
            > /etc/apt/sources.list.d/docker.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin buildx && \
        rm -rf /var/lib/apt/lists/* ; \
    fi

# --- Unprivileged runner user -------------------------------------------
RUN useradd --create-home --uid 1001 --shell /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner && \
    chmod 0440 /etc/sudoers.d/runner

WORKDIR ${RUNNER_HOME}

# --- Official GitHub Actions runner tarball ------------------------------
# Resolves the correct tarball architecture: an explicit RUNNER_ARCH build
# arg always wins, otherwise it's derived from TARGETARCH (set
# automatically by buildx for the platform being built).
RUN set -eu; \
    arch="${RUNNER_ARCH}"; \
    if [ -z "$arch" ]; then \
        case "${TARGETARCH}" in \
            amd64) arch=x64 ;; \
            arm64) arch=arm64 ;; \
            *) echo "Unsupported TARGETARCH='${TARGETARCH}'; set RUNNER_ARCH explicitly (x64|arm64)." >&2; exit 1 ;; \
        esac; \
    fi; \
    echo "Installing actions/runner v${RUNNER_VERSION} for linux-${arch}"; \
    curl -fsSL -o /tmp/actions-runner.tar.gz \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${arch}-${RUNNER_VERSION}.tar.gz" && \
    tar xzf /tmp/actions-runner.tar.gz -C "${RUNNER_HOME}" && \
    rm /tmp/actions-runner.tar.gz && \
    "${RUNNER_HOME}/bin/installdependencies.sh" && \
    chown -R runner:runner /home/runner

COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

USER runner
WORKDIR ${RUNNER_HOME}

# Fail the container early if the runner process dies (used by `docker ps`/orchestrators).
HEALTHCHECK --interval=60s --timeout=10s --start-period=90s --retries=3 \
    CMD test -f "${RUNNER_HOME}/.runner" || exit 1

ENTRYPOINT ["/home/runner/entrypoint.sh"]
