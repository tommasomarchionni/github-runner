# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial release: containerized self-hosted GitHub Actions runner built on
  the official `actions/runner` tarball.
- PAT-based authentication: registration and removal tokens are minted on
  the fly via the GitHub REST API, no manual token copy/paste required.
- Support for repository-scoped and organization-scoped runners.
- Configurable labels, runner group, work directory, ephemeral mode, and
  GitHub Enterprise Server endpoints via environment variables.
- Self-healing startup logic: automatically detects and recovers from a
  stale/invalid local registration on container recreation.
- Graceful shutdown: deregisters the runner from GitHub on `SIGTERM`/`SIGINT`.
- Docker Compose setup with a persistent named volume, plus a prebuilt-image
  variant (`docker-compose.prebuilt.yml`) using the GHCR image.
- Multi-arch (`amd64`/`arm64`) image published to GHCR on every push to
  `main` and on tagged releases.
- Full documentation site (MkDocs Material) deployed to GitHub Pages,
  including a dedicated Dokploy guide and a PAT permissions reference.
- Test suite: `shellcheck`, `hadolint`, `bats` unit tests for the entrypoint,
  and an automated image build, all wired into GitHub Actions CI.
- Open-source project scaffolding: Contributing guide, Code of Conduct,
  Security policy, issue/PR templates, and Dependabot configuration.

[Unreleased]: https://github.com/tommasomarchionni/github-runner/compare/main...HEAD
