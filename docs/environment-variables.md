# Environment variables

Every runtime behavior of this container — authentication scope, labels,
runner group, ephemeral mode, self-healing tuning, GitHub Enterprise
Server support — is controlled **exclusively through environment
variables**. There is no separate config file to edit and no UI-only
setting: what you see below is the complete, exhaustive list of what the
image supports, matching `docker/entrypoint.sh` exactly.

## Minimum required configuration

Only two variables are mandatory to start the container at all:

```env
GITHUB_PAT=ghp_xxx or github_pat_xxx
GITHUB_REPOSITORY=owner/repo
```

`GITHUB_PAT` is always required. For scope, set **either**
`GITHUB_REPOSITORY` **or** `GITHUB_ORG` — never both. Everything else in
this page has a working default and can be left unset.

## How variables reach the container

Where you set these variables depends on how you're running the image —
the variable *names* below are identical everywhere, but the mechanism
that delivers them to the container differs:

| Setup | Where you set them | Notes |
|---|---|---|
| [Docker Compose](docker-compose-guide.md) (`docker-compose.yml` / `docker-compose.prebuilt.yml`) | `.env` file next to the compose file, copied from `.env.example` | `docker compose` reads `.env` automatically and substitutes `${VAR_NAME}` into the compose file's `environment:` block, which is already wired up for every variable on this page |
| [Plain Docker](docker-plain.md) (`docker run`) | `-e VAR_NAME=value` flags, or `--env-file .env` | No compose file involved; you pass each variable explicitly on the command line |
| [Dokploy](dokploy.md) — Compose service | The service's **Environment** tab | Written to a `.env` file Dokploy manages; reaches the container only because the compose files use `${VAR_NAME}` interpolation — see the [Dokploy guide](dokploy.md#mode-a-compose-prebuilt-image-recommended) for the full explanation of this mechanism |
| [Dokploy](dokploy.md) — Application service | The service's **Environment** tab | Injected directly into the container, no compose file or interpolation involved |

If a variable you set doesn't seem to take effect, first confirm which of
these paths applies to your setup — a variable typed into a Dokploy
Compose service's Environment tab **will not** reach the container unless
the compose file references it, whereas the same field on an Application
service always will.

## Full reference

### Authentication and scope

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_PAT` | **Yes** | — | Personal Access Token, see [PAT permissions](pat-permissions.md) |
| `GITHUB_REPOSITORY` | One of this or `GITHUB_ORG` | — | `owner/repo` format, registers a repository-level runner |
| `GITHUB_ORG` | One of this or `GITHUB_REPOSITORY` | — | Registers an organization-level runner |
| `GITHUB_SERVER_URL` | No | `https://github.com` | Override for GitHub Enterprise Server, e.g. `https://ghe.example.com` |
| `GITHUB_API_URL` | No | `https://api.github.com` | For GHES, typically `https://ghe.example.com/api/v3` |

### Runner identity and behavior

| Variable | Required | Default | Description |
|---|---|---|---|
| `RUNNER_NAME` | No | container hostname | Name shown in GitHub's runner list |
| `RUNNER_LABELS` | No | (empty) | Comma-separated custom labels, added on top of the automatic `self-hosted`/OS/arch labels — see [Labels and runner groups](labels-and-groups.md) |
| `RUNNER_GROUP` | No | `Default` | Only relevant for organization/enterprise runners |
| `RUNNER_WORKDIR` | No | `_work` | Job working directory inside the container |
| `RUNNER_EPHEMERAL` | No | `false` | `true` = run a single job then self-deregister, see [Ephemeral runners](ephemeral.md) |
| `RUNNER_DISABLE_UPDATE` | No | `true` | Prevents the runner from attempting a self-update (recommended: update the image/`RUNNER_VERSION` instead) |
| `RUNNER_REPLACE` | No | `true` | Automatically replaces an already-registered runner with the same name, instead of failing registration |
| `RUNNER_UNREGISTER_TIMEOUT` | No | `30` | Seconds to wait for a clean stop (in-flight job to finish) before a forced kill |
| `LOG_LEVEL` | No | `info` | Set to `debug` for more verbose entrypoint logs (the PAT and tokens are never printed at any level) |
| `EXTRA_CONFIG_ARGS` | No | (empty) | Extra flags appended directly to `config.sh` (advanced; use only if you need a `config.sh` option this project doesn't otherwise expose) |

### Self-healing on restart/recreate

See [Persistence and self-healing](persistence.md) for the full behavior
these control.

| Variable | Required | Default | Description |
|---|---|---|---|
| `RUNNER_STARTUP_GRACE_SECONDS` | No | `20` | If `run.sh` exits within this many seconds of starting, the local registration is treated as stale and wiped |
| `RUNNER_START_MAX_ATTEMPTS` | No | `3` | Maximum number of registration attempts before giving up and exiting with a non-zero code |
| `RUNNER_FORCE_RECONFIGURE` | No | `false` | Set to `true` to force-wipe the local registration on the next start regardless of whether it looks valid (manual troubleshooting escape hatch); remember to set it back to `false` afterwards, or every future restart will re-register |

### Resource limits (Compose only)

These are read by `docker-compose.yml`/`docker-compose.prebuilt.yml`
themselves (as `mem_limit`/`cpus`), not by the entrypoint script — they
have no effect on a plain `docker run` unless you pass the equivalent
`--memory`/`--cpus` flags yourself.

| Variable | Required | Default | Description |
|---|---|---|---|
| `RUNNER_MEM_LIMIT` | No | `2g` | Hard memory limit for the container |
| `RUNNER_CPUS` | No | `2.0` | CPU limit for the container |
| `RUNNER_VOLUME_NAME` | No | `github-runner-data` | Name of the persistent Docker volume — override this if you run multiple runner instances on the same host, so each gets its own volume |

### Build arguments (Dockerfile, build time only)

These are `ARG`s consumed while **building** the image — they are not
environment variables of the running container and have no effect if you
set them at `docker run`/Compose `environment:` time instead of at build
time (`--build-arg` or the Compose `build.args:` block).

| Build arg | Default | Description |
|---|---|---|
| `RUNNER_VERSION` | `2.337.0` | Version of the official `actions/runner` tarball to install |
| `RUNNER_ARCH` | auto-detected from `TARGETARCH` | Tarball architecture (`x64`, `arm64`); leave empty unless cross-building for a different target than your build host, see [Platform setup](platform-setup.md#architecture-reference) |
| `INSTALL_DOCKER_CLI` | `true` | Bundles the Docker CLI (client only) in the image, see [Docker inside workflows](docker-in-workflow.md) |

## Where these are already wired up for you

You rarely need to type this list from scratch: `.env.example` at the
repository root already lists every variable above with a short comment
and a sensible default — copy it to `.env` and fill in only what your
setup needs. `docker-compose.yml` and `docker-compose.prebuilt.yml` both
already reference every one of these variables in their `environment:`
block, so setting a value in `.env` (or in Dokploy's Environment tab for a
Compose service) is always sufficient — no compose file edits required.
