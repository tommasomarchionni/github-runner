# GitHub Runner (Docker, PAT-based, persistent)

A containerized self-hosted runner for GitHub Actions, built **exclusively
on the official [`actions/runner`](https://github.com/actions/runner)
release tarball** (no third-party runner images). It uses a **Personal
Access Token (PAT)** to mint a fresh registration token from the GitHub API
on every start, so the container can be stopped, recreated, or redeployed
any number of times without ever going back to the "New self-hosted
runner" page to copy a token by hand.

## Why this project

- **No third-party images**: built directly from the official tarball
  published by GitHub.
- **PAT instead of a temporary registration token**: no more one-hour
  windows to complete a deploy.
- **Self-healing**: if the container is destroyed and recreated and the
  registration stored in the volume turns out to be invalid, it
  re-registers itself automatically (see
  [Persistence and self-healing](persistence.md)).
- **Deeply configurable**: repository/organization scope, labels, runner
  group, ephemeral mode, GitHub Enterprise Server — all via environment
  variables (see [Environment variables](environment-variables.md)).
- **Tested**: shellcheck, hadolint, bats unit tests, and an automated build
  on every push (see [Testing and CI](testing.md)).

## How it works

1. On startup, the entrypoint (`docker/entrypoint.sh`) calls the GitHub
   REST API with your PAT to obtain a **registration token** valid for
   about one hour.
2. If no valid registration exists yet in the persistent volume, it runs
   `config.sh` with that token and your configured name, group, and
   labels.
3. It starts `run.sh` and listens for jobs.
4. On `SIGTERM`/`SIGINT` (container stop), it requests a fresh **removal
   token** and deregisters the runner from GitHub before exiting, so you
   never end up with "ghost" runners in the Settings page.

The PAT is never written to disk: it only lives as an environment variable
of the container and is used on the fly for API calls.

## Where to start

<div class="grid cards" markdown>

- **Start here**: configure the [PAT permissions](pat-permissions.md) —
  this is the number one source of problems.
- **Fastest path**: pull the [prebuilt image](prebuilt-image.md) from GHCR,
  no build step required.
- **Docker Compose** locally or on a server: see the
  [Docker Compose guide](docker-compose-guide.md).
- **Dokploy**: see the dedicated [Dokploy guide](dokploy.md).
- **Plain Docker** without Compose: see [Plain Docker](docker-plain.md).

</div>

## Repository

Source code, issues, and pull requests:
[github.com/tommasomarchionni/github-runner](https://github.com/tommasomarchionni/github-runner).
