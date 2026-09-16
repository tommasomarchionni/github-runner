# Platform setup: macOS, Windows, Linux

Everything in this project runs the same way on every platform: it's a
single Docker container. The only platform-specific work is **installing
Docker itself** and knowing a few OS-specific quirks before you run the
commands in [Docker Compose](docker-compose-guide.md) or
[Plain Docker](docker-plain.md). If you're deploying to
[Dokploy](dokploy.md) instead, Dokploy already runs on a Linux host with
Docker installed for you — skip straight to that guide.

=== "macOS"

    ## Install Docker

    Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
    (Apple Silicon or Intel build, matching your Mac). It bundles the
    Docker Engine, the CLI, and Docker Compose v2 — no separate install
    needed.

    Verify it from a terminal:

    ```bash
    docker --version
    docker compose version
    ```

    ## Apple Silicon (M1/M2/M3/M4)

    - Leave `RUNNER_ARCH` **empty** in `.env` (the default). The Dockerfile
      auto-detects `arm64` from Docker Desktop's build platform and pulls
      the matching `actions/runner` tarball — you get a native arm64
      image, not an emulated one.
    - If you explicitly need an `x64` image (e.g. to exactly match a
      production Linux host's architecture), set `RUNNER_ARCH=x64`, but
      expect a slower build and runtime under Rosetta emulation.
    - The [prebuilt image](prebuilt-image.md) on GHCR is already
      multi-arch (`linux/amd64` + `linux/arm64`): Docker pulls the correct
      variant for your Mac automatically, so there's nothing to configure.

    ## Resource limits

    Docker Desktop enforces its **own** global CPU/memory cap (Settings →
    Resources) on top of this project's `RUNNER_MEM_LIMIT`/`RUNNER_CPUS`
    variables. If a workflow job is unexpectedly slow or OOM-killed, check
    Docker Desktop's Resources settings first, not just the `.env` values.

    ## File sharing performance

    Keep the cloned repository on your normal home-directory filesystem
    (e.g. `~/Projects/github-runner`) — no special file-sharing
    configuration is required on macOS, unlike Windows/WSL2.

=== "Windows"

    ## Install Docker

    Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
    with the **WSL 2 backend** (the default and recommended option — the
    legacy Hyper-V backend also works but is slower and being phased out
    by Docker itself).

    Verify from either PowerShell or a WSL terminal:

    ```powershell
    docker --version
    docker compose version
    ```

    ## Clone the repository inside WSL, not on `C:\`

    If you use the WSL 2 backend, clone this repository **inside the WSL
    filesystem** (e.g. `\\wsl$\Ubuntu\home\<user>\github-runner` /
    `~/github-runner` from a WSL shell), not under `/mnt/c/...`. Docker
    Desktop's bind-mount performance across the Windows/Linux filesystem
    boundary is significantly slower, and `docker compose up --build`
    will take noticeably longer if the build context sits on the Windows
    side.

    ```bash
    # from a WSL (Ubuntu) terminal, not PowerShell
    git clone https://github.com/tommasomarchionni/github-runner.git
    cd github-runner
    cp .env.example .env
    ```

    ## Running the commands

    Every command in [Docker Compose](docker-compose-guide.md) and
    [Plain Docker](docker-plain.md) is written for a POSIX shell (bash).
    Run them from a **WSL terminal** (Ubuntu, Debian, ...) rather than
    PowerShell or `cmd.exe` — Docker Desktop's WSL 2 integration exposes
    the same `docker` CLI inside WSL with no extra setup. If you must use
    native PowerShell instead, replace shell-specific syntax (line
    continuations, `${VAR}` expansion in `.env`) accordingly; the
    `docker compose` commands themselves are identical.

    ## Line endings

    Git for Windows may check out shell scripts with CRLF line endings by
    default, which breaks `bash` scripts if you ever edit and rebuild
    `docker/entrypoint.sh` yourself. If you plan to modify it, set:

    ```bash
    git config --global core.autocrlf input
    ```

    before cloning, or add a `.gitattributes` entry forcing `*.sh
    text eol=lf`. This does **not** affect the prebuilt image or an
    unmodified clone — Docker builds the image from the repository's
    checked-in line endings either way, so this only matters if you edit
    the script locally before rebuilding.

=== "Linux"

    ## Install Docker Engine

    Linux has no Docker Desktop requirement — install the Docker Engine
    and Compose plugin directly from your distribution's package manager
    or Docker's official repositories, for example on Ubuntu/Debian:

    ```bash
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    # log out and back in for the group change to take effect
    ```

    Verify:

    ```bash
    docker --version
    docker compose version
    ```

    ## Running without `sudo`

    After adding your user to the `docker` group above, you can run every
    command in this documentation without `sudo`. If you skip that step,
    prefix `docker`/`docker compose` commands with `sudo` instead.

    ## systemd and reboots

    `restart: unless-stopped` in `docker-compose.yml` (or `--restart
    unless-stopped` in the plain `docker run` command) already brings the
    runner back after a host reboot, as long as the Docker daemon itself
    is enabled to start on boot:

    ```bash
    sudo systemctl enable docker
    ```

    ## This is also what Dokploy runs on

    If you're evaluating whether to self-host with plain Docker or move to
    [Dokploy](dokploy.md) later: Dokploy itself is a self-hosted PaaS that
    runs on exactly this kind of Linux host and manages the same Docker
    Engine for you through a web UI, so nothing here is wasted effort.

## Architecture reference

| Host architecture | `RUNNER_ARCH` | Result |
|---|---|---|
| Apple Silicon Mac, ARM-based Linux server | leave empty (auto-detect) | Native `arm64` build/image |
| Intel/AMD Mac, Windows, most Linux servers | leave empty (auto-detect) | Native `x64` build/image |
| Cross-building for a different target than your build host | set explicitly (`x64` or `arm64`) | Forces that tarball; combine with `docker buildx build --platform ...` for cross-compilation |

See [Troubleshooting](troubleshooting.md#building-on-apple-silicon-arm-produces-an-x64-binary-or-fails-at-runtime)
if a build produces the wrong architecture.
