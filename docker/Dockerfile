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
# The Playwright version the bundled browser is installed for. A project whose
# lock file names another version installs its own browser in the job (see
# docs/bundled-tools.md, "Playwright browser"): keep it equal to the version of
# the projects that use this image. Declared before the first FROM so that both
# stages below see the same default.
ARG PLAYWRIGHT_VERSION=1.65.1

# --- Build stage: the Playwright command line, only to install the browser --
# Node.js and playwright-core never reach the final image: the browser step
# below mounts this stage for the length of one RUN. The node binary of the
# official image runs on the Ubuntu base (glibc is newer there).
FROM node:22.23.4-bookworm-slim AS playwright-cli
ARG PLAYWRIGHT_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /opt/playwright-cli/bin && \
    cp /usr/local/bin/node /opt/playwright-cli/bin/node && \
    npm install --prefix /opt/playwright-cli --no-audit --no-fund --ignore-scripts \
        "playwright-core@${PLAYWRIGHT_VERSION}" && \
    /opt/playwright-cli/bin/node /opt/playwright-cli/node_modules/playwright-core/cli.js --version \
        | grep -qx "Version ${PLAYWRIGHT_VERSION}"

# Ubuntu LTS, the release GitHub-hosted runners use (`ubuntu-24.04`). Keep it on
# an LTS: the `setup-*` actions (setup-python, setup-node, ...) and browser
# installers publish prebuilt binaries for the hosted-runner LTS releases only,
# so on an interim release (25.04, 25.10) they fail with "version not found".
# Dependabot is told to leave major bumps of this image alone; move to the next
# LTS by hand once GitHub-hosted runners offer it.
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
ARG INSTALL_DOCKER_CLI=true
# Set to "true" to install the GitHub CLI (`gh`), which workflows commonly use to
# call the GitHub API, comment on pull requests or merge them.
ARG INSTALL_GH_CLI=true
# Set to "true" to install a C/C++ toolchain and a system Python (python3, venv,
# pip, pipx): what native npm/pip packages and helper scripts expect to find,
# as they do on GitHub-hosted runners.
ARG INSTALL_BUILD_TOOLS=true
# Set to "true" to install uv, the Python package and project manager, as the
# official static binary. The version and the SHA-256 of each architecture's
# archive are pinned (published by astral-sh/uv with the release, checked here
# at build time): move the three values together to update it.
ARG INSTALL_UV=true
ARG UV_VERSION=0.13.3
ARG UV_SHA256_AMD64=e4f169ec380f1793b898a6f1fcbacd22db25cf7ca0349a6e96ffb85b69998d04
ARG UV_SHA256_ARM64=611ff684f193a84d2fdad29c5f12505d02ece94984c7c982cdde950eba5c95b9
# Set to "true" to install the Chromium browser of Playwright, at the version
# above, with the system libraries it needs (what `playwright install
# --with-deps chromium` would install in every job), so that a job runs browser
# tests without apt. See docs/bundled-tools.md, "Playwright browser".
ARG INSTALL_PLAYWRIGHT_CHROMIUM=true
ARG PLAYWRIGHT_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_VERSION=${RUNNER_VERSION} \
    RUNNER_HOME=/home/runner/actions-runner \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/home/runner/.local/bin:${PATH}

# Fail a RUN line if any command in a pipe fails, not just the last one —
# needed below where the ICU package name is piped through several
# filters before being installed.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- Base packages -----------------------------------------------------
# Versions are intentionally not pinned: this image tracks Ubuntu's
# rolling package repositories, and pinned versions age out of the
# archive and break reproducible builds within weeks. Freshness is
# preferred here over pinning; Dependabot still tracks the base image tag.
#
# libicu's SONAME bumps on almost every Ubuntu release (libicu74 on 24.04,
# libicu76 on 25.04, ...), so a hardcoded package name breaks the very
# next time Dependabot proposes a base image bump. Resolve the ICU runtime
# package actually shipped by the base image's own repositories instead of
# hardcoding a version — this keeps the build working across future Ubuntu
# releases with no Dockerfile change required.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        file \
        git \
        git-lfs \
        gnupg \
        iproute2 \
        jq \
        lsb-release \
        lsof \
        openssh-client \
        psmisc \
        rsync \
        sudo \
        tar \
        tzdata \
        unzip \
        wget \
        xz-utils \
        zip \
        zstd \
        && \
    icu_pkg="$(apt-cache search --names-only '^libicu[0-9]+$' | awk '{print $1}' | sort -V | tail -n1)" && \
    [ -n "${icu_pkg}" ] || { echo 'No libicu<N> package found in apt cache' >&2; exit 1; } && \
    echo "Resolved ICU runtime package: ${icu_pkg}" && \
    apt-get install -y --no-install-recommends "${icu_pkg}" && \
    rm -rf /var/lib/apt/lists/*

# --- Optional Docker CLI (client only, uses the host's mounted socket) --
# DL3008: same rolling-repository rationale as above.
# SC1091: `. /etc/os-release` is sourced from the target filesystem at
# build time, not from a file hadolint can statically follow — a known,
# harmless false positive for this exact pattern.
# hadolint ignore=DL3008,SC1091
RUN if [ "$INSTALL_DOCKER_CLI" = "true" ]; then \
        install -m 0755 -d /etc/apt/keyrings && \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
        chmod a+r /etc/apt/keyrings/docker.asc && \
        . /etc/os-release && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
            > /etc/apt/sources.list.d/docker.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin && \
        rm -rf /var/lib/apt/lists/* ; \
    fi

# --- Optional GitHub CLI (`gh`) ------------------------------------------
# Installed from GitHub's own apt repository, verified with its signing key.
# DL3008: same rolling-repository rationale as above.
# hadolint ignore=DL3008
RUN if [ "$INSTALL_GH_CLI" = "true" ]; then \
        install -m 0755 -d /etc/apt/keyrings && \
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
        chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            > /etc/apt/sources.list.d/github-cli.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends gh && \
        rm -rf /var/lib/apt/lists/* && \
        gh --version ; \
    fi

# --- Optional build tools: C/C++ toolchain and system Python --------------
# Needed when an npm or pip package has no prebuilt binary and compiles on
# install, and by scripts that call `python3` without a setup action.
# DL3008: same rolling-repository rationale as above.
# hadolint ignore=DL3008
RUN if [ "$INSTALL_BUILD_TOOLS" = "true" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            build-essential \
            pipx \
            python3 \
            python3-pip \
            python3-venv \
            && \
        rm -rf /var/lib/apt/lists/* && \
        gcc --version && python3 --version ; \
    fi

# --- Optional uv (official static binary, pinned and verified) -------------
# The release archive of astral-sh/uv for the build platform, checked against
# the SHA-256 above before anything is extracted; `uv` and `uvx` go to
# /usr/local/bin (root-owned, on every user's PATH), nothing else is kept. No
# installer script and no pip: the build fails if the checksum does not match.
RUN if [ "$INSTALL_UV" = "true" ]; then \
        set -eu; \
        case "${TARGETARCH}" in \
            amd64) triple=x86_64-unknown-linux-gnu; sha="${UV_SHA256_AMD64}" ;; \
            arm64) triple=aarch64-unknown-linux-gnu; sha="${UV_SHA256_ARM64}" ;; \
            *) echo "Unsupported TARGETARCH='${TARGETARCH}' for uv (amd64|arm64)." >&2; exit 1 ;; \
        esac; \
        curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/uv.tar.gz \
            "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${triple}.tar.gz" && \
        echo "${sha}  /tmp/uv.tar.gz" | sha256sum -c - && \
        tar -xzf /tmp/uv.tar.gz -C /usr/local/bin --strip-components=1 \
            "uv-${triple}/uv" "uv-${triple}/uvx" && \
        rm /tmp/uv.tar.gz && \
        uv --version | grep -qx "uv ${UV_VERSION}.*" && uv --version ; \
    fi

# --- Unprivileged runner user -------------------------------------------
RUN useradd --create-home --uid 1001 --shell /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner && \
    chmod 0440 /etc/sudoers.d/runner

# --- Optional Playwright Chromium and its system libraries -------------------
# PLAYWRIGHT_BROWSERS_PATH is where Playwright looks for browsers and installs
# them: one directory for every user, owned by the runner user so a job can add
# the browser of another Playwright version without sudo. It exists, empty, in
# an image built without the browser too.
#
# The packages are the ones `playwright install-deps chromium` installs on
# Ubuntu 24.04 (amd64 and arm64 share the list): the X server and fonts of its
# "tools" group, which the browser uses to render text and run headed, then the
# libraries of Chromium. They are listed here, not left to `install-deps`, so
# the image says what it carries; the build then asks Playwright itself
# (`install-deps --dry-run`, which simulates the installation with apt) and
# fails unless every dependency is installed, so a list that falls behind a
# new Playwright version stops the build instead of the jobs.
# `install chromium` brings Chrome for Testing, its headless shell and ffmpeg.
# The file .playwright-version records the Playwright version the browser is
# for: a job compares it with its own lock file.
# DL3008: same rolling-repository rationale as above.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
# hadolint ignore=DL3008
RUN --mount=type=bind,from=playwright-cli,source=/opt/playwright-cli,target=/opt/playwright-cli \
    install -d -o runner -g runner "${PLAYWRIGHT_BROWSERS_PATH}" && \
    if [ "$INSTALL_PLAYWRIGHT_CHROMIUM" = "true" ]; then \
        set -eu ; \
        playwright() { /opt/playwright-cli/bin/node /opt/playwright-cli/node_modules/playwright-core/cli.js "$@"; }; \
        apt-get update ; \
        apt-get install -y --no-install-recommends \
            fonts-freefont-ttf \
            fonts-ipafont-gothic \
            fonts-liberation \
            fonts-noto-color-emoji \
            fonts-tlwg-loma-otf \
            fonts-unifont \
            fonts-wqy-zenhei \
            libfontconfig1 \
            libfreetype6 \
            xfonts-cyrillic \
            xfonts-scalable \
            xvfb \
            libasound2t64 \
            libatk-bridge2.0-0t64 \
            libatk1.0-0t64 \
            libatspi2.0-0t64 \
            libcairo2 \
            libcups2t64 \
            libdbus-1-3 \
            libdrm2 \
            libgbm1 \
            libglib2.0-0t64 \
            libnspr4 \
            libnss3 \
            libpango-1.0-0 \
            libx11-6 \
            libxcb1 \
            libxcomposite1 \
            libxdamage1 \
            libxext6 \
            libxfixes3 \
            libxkbcommon0 \
            libxrandr2 ; \
        playwright install chromium ; \
        playwright install-deps --dry-run chromium | tee /tmp/playwright-deps.txt ; \
        grep -qx 'All system dependencies are installed.' /tmp/playwright-deps.txt ; \
        rm -rf /var/lib/apt/lists/* /tmp/playwright-deps.txt ; \
        executables="$(find "${PLAYWRIGHT_BROWSERS_PATH}" -type f -perm -u+x \
            \( -name chrome -o -name chrome-headless-shell \) | sort)" ; \
        if [ "$(printf '%s\n' "${executables}" | grep -c .)" -ne 2 ]; then \
            echo "Expected chrome and chrome-headless-shell, found: ${executables}" >&2; exit 1; \
        fi ; \
        printf '%s\n' "${executables}" | while read -r executable; do \
            if ldd "${executable}" | grep 'not found'; then \
                echo "${executable} lacks a system library" >&2; exit 1; \
            fi ; \
        done ; \
        echo "${PLAYWRIGHT_VERSION}" > "${PLAYWRIGHT_BROWSERS_PATH}/.playwright-version" ; \
        chown -R runner:runner "${PLAYWRIGHT_BROWSERS_PATH}" ; \
        ls -la "${PLAYWRIGHT_BROWSERS_PATH}" ; \
    fi

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

# Runs before every job and removes broken tracking refs from the working copy (docs/persistence.md).
# Set ACTIONS_RUNNER_HOOK_JOB_STARTED to another script, or to an empty value, to replace or drop it.
COPY --chown=runner:runner job-started.sh /home/runner/job-started.sh
RUN chmod +x /home/runner/job-started.sh
ENV ACTIONS_RUNNER_HOOK_JOB_STARTED=/home/runner/job-started.sh

USER 1001
WORKDIR ${RUNNER_HOME}

# Fail the container early if the runner process dies (used by `docker ps`/orchestrators).
HEALTHCHECK --interval=60s --timeout=10s --start-period=90s --retries=3 \
    CMD ["/bin/bash", "-c", "test -f \"${RUNNER_HOME}/.runner\""]

ENTRYPOINT ["/home/runner/entrypoint.sh"]
