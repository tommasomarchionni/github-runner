# Bundled tools

A workflow written for GitHub-hosted runners expects a number of
command-line tools to be there. This image bundles the ones that jobs and
actions call most often, so the same workflow runs here without an
"install it first" step, and leaves the rest to `setup-*` actions.

## Base image: Ubuntu LTS

The image is built on **Ubuntu 24.04 LTS**, the release behind
`ubuntu-24.04`/`ubuntu-latest` on GitHub-hosted runners, and it stays on an
LTS on purpose. The `setup-*` actions (`actions/setup-python`,
`actions/setup-node`, …) and browser installers such as Playwright download
prebuilt binaries published for the hosted-runner releases only. On an
interim release they fail, for example:

```text
The version '3.12' with architecture 'x64' was not found for Ubuntu 25.10.
```

Dependabot is configured to ignore major and minor bumps of the base image:
Ubuntu tags are `YY.MM`, so both `24.04 → 25.10` and `24.04 → 24.10` look like
ordinary version bumps and both land on an interim release. An interim release
also loses its package archive nine months after it ships, and from then on the
image no longer builds. Move to the next LTS by hand, once GitHub-hosted
runners offer it, and run the [bundled tools test](testing.md#bundled-tools-test):
it asserts the release.

## Always in the image

| Tool | Typical use |
|---|---|
| `git`, `git-lfs` | checkout, repositories with large files |
| `curl`, `wget` | downloads in install scripts |
| `jq` | JSON in shell steps |
| `tar`, `zip`, `unzip`, `xz`, `zstd`, `bzip2` | archives; `actions/cache` uses `zstd` when it finds it |
| `rsync`, `ssh` (client) | deploys that copy files, Git over SSH |
| `file`, `gnupg`, `lsb-release`, `sudo` | checks and signatures in install scripts |
| `ip` (`iproute2`) | network troubleshooting |

## Bundled by default, optional

Each group has a build argument, `true` by default. Set it to `false` when
building from source for a smaller image; the prebuilt GHCR image includes
all of them.

| Build argument | What it adds | Size |
|---|---|---|
| `INSTALL_DOCKER_CLI` | Docker CLI, Compose and Buildx plugins (client only), see [Docker inside workflows](docker-in-workflow.md) | — |
| `INSTALL_GH_CLI` | GitHub CLI (`gh`), see [GitHub CLI inside workflows](github-cli.md) | — |
| `INSTALL_BUILD_TOOLS` | `build-essential` (`gcc`, `g++`, `make`) and a system Python: `python3`, `python3-venv`, `python3-pip`, `pipx` | about 440 MB |

### Build tools and Python

The toolchain is what `npm install` and `pip install` need when a package
has no prebuilt binary for the platform and compiles on install.

The system Python is there for scripts that call `python3` directly. It
follows the distribution's rules:

- `pip install` outside a virtual environment is refused (PEP 668). Use a
  virtual environment (`python3 -m venv .venv`), or `pipx install <tool>` for
  command-line tools: `~/.local/bin` is on `PATH`.
- For a specific Python version, keep using
  [`actions/setup-python`](https://github.com/actions/setup-python): the
  system Python is whatever the base image ships.

## Deliberately not bundled

Language runtimes and SDKs (Node.js, Java, .NET, Go, Ruby, PHP, Rust), cloud
CLIs (`aws`, `az`, `gcloud`), `kubectl`, `helm` and Terraform are **not** in
the image. They would add gigabytes, age quickly, and every project needs
its own version. Install them with their `setup-*` action
(`actions/setup-node`, `actions/setup-java`, …): the runner's tool cache
lives in the persistent work volume, so a version is downloaded once and
reused by later jobs.

Browser dependencies (for Playwright, Puppeteer, Cypress) are not bundled
either: install them in the job, for example
`npx playwright install --with-deps chromium`. The `runner` user has
passwordless `sudo` for this.

## Adding a tool

- **For one project:** install it in the workflow, with its `setup-*` action
  or a step.
- **For every job on your runner:** build from source and add the package to
  the Dockerfile, see [Docker Compose](docker-compose-guide.md).

## Checking what a running runner has

Run the [smoke test](testing.md#end-to-end-smoke-test) against it: it
prints the version of every bundled tool and fails if a base tool is
missing. A runner keeps the image it was created with until it is
redeployed, see [Updating a running runner](github-cli.md#updating-a-running-runner).
