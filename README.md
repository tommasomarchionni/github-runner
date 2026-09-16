# GitHub Runner (Docker, PAT-based, persistent)

[![CI](https://github.com/tommasomarchionni/github-runner/actions/workflows/ci.yml/badge.svg)](https://github.com/tommasomarchionni/github-runner/actions/workflows/ci.yml)
[![Publish image](https://github.com/tommasomarchionni/github-runner/actions/workflows/publish-image.yml/badge.svg)](https://github.com/tommasomarchionni/github-runner/actions/workflows/publish-image.yml)
[![Docs](https://github.com/tommasomarchionni/github-runner/actions/workflows/docs.yml/badge.svg)](https://github.com/tommasomarchionni/github-runner/actions/workflows/docs.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-tommasomarchionni%2Fgithub--runner-blue?logo=docker)](https://github.com/tommasomarchionni/github-runner/pkgs/container/github-runner)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A containerized self-hosted runner for GitHub Actions, built **only on the
official [`actions/runner`](https://github.com/actions/runner) release**
(no third-party runner images), authenticated with a **Personal Access
Token** so it can be stopped, redeployed, and recreated indefinitely
without ever copying a temporary registration token by hand.

**Full documentation:** [tommasomarchionni.github.io/github-runner](https://tommasomarchionni.github.io/github-runner/)

## Highlights

- Official `actions/runner` tarball only, multi-arch (`amd64`/`arm64`)
- PAT-based registration — no one-hour token windows
- Self-healing: recovers automatically from a stale registration after the
  container is destroyed and recreated
- Fully configurable via environment variables: repo/org scope, labels,
  runner group, ephemeral mode, GitHub Enterprise Server
- Graceful shutdown: deregisters itself from GitHub on stop
- Prebuilt multi-arch image published to GHCR, or build it yourself
- Tested: shellcheck, hadolint, bats unit tests, automated CI build
- Ready for Docker Compose, plain Docker, and Dokploy

## Quick start

```bash
git clone https://github.com/tommasomarchionni/github-runner.git
cd github-runner
cp .env.example .env
# edit .env: set GITHUB_PAT and GITHUB_REPOSITORY (see the PAT permissions docs)

docker compose up -d --build
docker compose logs -f github-runner
```

Or skip the build entirely with the prebuilt image:

```bash
docker compose -f docker-compose.prebuilt.yml up -d
```

See the [Quick start guide](https://tommasomarchionni.github.io/github-runner/docker-compose-guide/)
for details, and [PAT permissions](https://tommasomarchionni.github.io/github-runner/pat-permissions/)
before creating your token. New to Docker on your OS? See
[Platform setup for macOS, Windows, and Linux](https://tommasomarchionni.github.io/github-runner/platform-setup/).

## Documentation

| Topic | Link |
|---|---|
| PAT permissions | [docs](https://tommasomarchionni.github.io/github-runner/pat-permissions/) |
| Platform setup (macOS, Windows, Linux) | [docs](https://tommasomarchionni.github.io/github-runner/platform-setup/) |
| Prebuilt image (GHCR) | [docs](https://tommasomarchionni.github.io/github-runner/prebuilt-image/) |
| Docker Compose | [docs](https://tommasomarchionni.github.io/github-runner/docker-compose-guide/) |
| Dokploy (all deployment modes) | [docs](https://tommasomarchionni.github.io/github-runner/dokploy/) |
| Plain Docker | [docs](https://tommasomarchionni.github.io/github-runner/docker-plain/) |
| Environment variables (full reference) | [docs](https://tommasomarchionni.github.io/github-runner/environment-variables/) |
| Labels and runner groups | [docs](https://tommasomarchionni.github.io/github-runner/labels-and-groups/) |
| Persistence and self-healing | [docs](https://tommasomarchionni.github.io/github-runner/persistence/) |
| Security | [docs](https://tommasomarchionni.github.io/github-runner/security/) |
| Testing and CI | [docs](https://tommasomarchionni.github.io/github-runner/testing/) |
| Troubleshooting | [docs](https://tommasomarchionni.github.io/github-runner/troubleshooting/) |

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Please
follow the [Code of Conduct](CODE_OF_CONDUCT.md). For security issues, see
[SECURITY.md](SECURITY.md) instead of opening a public issue.

## License

[MIT](LICENSE) © Tommaso Marchionni
