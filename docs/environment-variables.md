# Environment variables

## Authentication and scope

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_PAT` | Yes | — | Personal Access Token, see [PAT permissions](pat-permissions.md) |
| `GITHUB_REPOSITORY` | One of this or `GITHUB_ORG` | — | `owner/repo` format, registers a repository-level runner |
| `GITHUB_ORG` | One of this or `GITHUB_REPOSITORY` | — | Registers an organization-level runner |
| `GITHUB_SERVER_URL` | No | `https://github.com` | Override for GitHub Enterprise Server |
| `GITHUB_API_URL` | No | `https://api.github.com` | For GHES, typically `https://HOSTNAME/api/v3` |

## Runner identity and behavior

| Variable | Required | Default | Description |
|---|---|---|---|
| `RUNNER_NAME` | No | container hostname | Name shown in GitHub |
| `RUNNER_LABELS` | No | (empty) | Comma-separated custom labels, added on top of `self-hosted`/OS/arch |
| `RUNNER_GROUP` | No | `Default` | Only relevant for organization/enterprise runners |
| `RUNNER_WORKDIR` | No | `_work` | Job working directory inside the container |
| `RUNNER_EPHEMERAL` | No | `false` | `true` = run a single job then self-deregister, see [Ephemeral runners](ephemeral.md) |
| `RUNNER_DISABLE_UPDATE` | No | `true` | Prevents the runner from attempting a self-update |
| `RUNNER_REPLACE` | No | `true` | Automatically replaces an already-registered runner with the same name |
| `RUNNER_UNREGISTER_TIMEOUT` | No | `30` | Seconds to wait for a clean stop before a forced kill |
| `LOG_LEVEL` | No | `info` | Set to `debug` for more verbose logs (the PAT/tokens are never printed) |
| `EXTRA_CONFIG_ARGS` | No | (empty) | Extra flags passed directly to `config.sh` (advanced) |

## Self-healing on restart/recreate

See [Persistence and self-healing](persistence.md) for full context.

| Variable | Required | Default | Description |
|---|---|---|---|
| `RUNNER_STARTUP_GRACE_SECONDS` | No | `20` | If `run.sh` exits within this many seconds of starting, the local registration is treated as stale and wiped |
| `RUNNER_START_MAX_ATTEMPTS` | No | `3` | Maximum number of registration attempts before giving up |
| `RUNNER_FORCE_RECONFIGURE` | No | `false` | Set to `true` to force-wipe the local registration on the next start (manual troubleshooting escape hatch); remember to set it back to `false` afterwards |

## Build arguments (Dockerfile)

| Build arg | Default | Description |
|---|---|---|
| `RUNNER_VERSION` | `2.337.0` | Version of the official `actions/runner` tarball to install |
| `RUNNER_ARCH` | `x64` | Tarball architecture (`x64`, `arm64`, ...) |
| `INSTALL_DOCKER_CLI` | `false` | Installs the Docker CLI in the image, see [Docker inside workflows](docker-in-workflow.md) |
