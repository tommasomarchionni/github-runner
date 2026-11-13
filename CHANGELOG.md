# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Base image back to Ubuntu 24.04 LTS, the release GitHub-hosted runners use.
  A Dependabot bump to the interim 25.10 release made `actions/setup-python`
  (and any other `setup-*` action without a cached tool) fail with "The version
  ... was not found for Ubuntu 25.10". Dependabot now ignores major and minor
  bumps of the base image (24.04 → 25.10 and 24.04 → 24.10 are both interim
  releases), a test checks that rule, and the image test asserts the LTS.

### Added

- Everyday tools of GitHub-hosted runners in the base image: `git-lfs`, `zip`,
  `xz-utils`, `zstd`, `bzip2`, `file`, `wget`, `rsync` and an SSH client
  (`openssh-client`). `zstd` lets `actions/cache` use its faster format.
- C/C++ toolchain (`build-essential`) and system Python (`python3`, `venv`,
  `pip`, `pipx`) bundled by default behind the `INSTALL_BUILD_TOOLS` build
  argument (`true` by default, about 440 MB; set it to `false` for a smaller
  image). `~/.local/bin` is on `PATH`, so tools installed with `pipx` are found.
- `tests/test_image_tools.sh`: checks the bundled tools inside a built image,
  for the default image and for one built without the build tools; run by
  `tests/run-tests.sh` and by CI.
- GitHub CLI (`gh`) bundled in the image by default (`INSTALL_GH_CLI` build
  argument, `true` by default): workflows that call `gh` no longer fail with
  "command not found" on this runner.
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
