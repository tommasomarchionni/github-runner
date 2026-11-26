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
| `fuser` (`psmisc`), `lsof` | which process holds a file or a lock (apt, dpkg, a port) |

## Bundled by default, optional

Each group has a build argument, `true` by default. Set it to `false` when
building from source for a smaller image; the prebuilt GHCR image includes
all of them.

| Build argument | What it adds | Size |
|---|---|---|
| `INSTALL_DOCKER_CLI` | Docker CLI, Compose and Buildx plugins (client only), see [Docker inside workflows](docker-in-workflow.md) | — |
| `INSTALL_GH_CLI` | GitHub CLI (`gh`), see [GitHub CLI inside workflows](github-cli.md) | — |
| `INSTALL_UV` | `uv` and `uvx` (the Python package and project manager), see [uv](#uv) | about 40 MB |
| `INSTALL_PLAYWRIGHT_CHROMIUM` | Chromium of Playwright (Chrome for Testing, its headless shell, ffmpeg) and the system libraries and fonts it needs, see [Playwright browser](#playwright-browser) | several hundred MB |
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

### uv

`uv` is the official static binary of [astral-sh/uv](https://github.com/astral-sh/uv),
installed in `/usr/local/bin` for the `linux/amd64` and `linux/arm64` images. The
Dockerfile pins the version (`UV_VERSION`) and the SHA-256 of each architecture's
release archive (`UV_SHA256_AMD64`, `UV_SHA256_ARM64`, the values published with the
release on GitHub); the build fails when a checksum does not match, and there is no
installer script and no `pip` involved. It does not need the system Python: `uv`
manages Python versions and environments itself.

To update it, change the three values together, taking the checksums from the
`.sha256` files of the release page, and rebuild. A project that pins a `uv`
version in its own checks (`uv --version` equal to a constant) moves that constant
with the image. Dependabot does not follow this pin: it is a release asset, not an
image.

### Playwright browser

The Node.js that runs `playwright-core` in the `playwright-cli` stage stays on the major
version of the base image: its binary is copied into the Ubuntu image, and a newer major
needs system libraries Ubuntu does not ship (`libatomic`). Dependabot ignores its major
bumps (`.github/dependabot.yml`); move it by hand and rebuild.

Browser tests need Chromium and about thirty system packages (libraries, an X
server, fonts). Installed by every job (`npx playwright install --with-deps
chromium`), they cost minutes of `apt` per job, depend on the package mirrors,
and on a long-lived runner an `apt` left hanging by a cancelled job holds the
package lock for every later job. The image installs them once, at build time,
for `linux/amd64` and `linux/arm64`:

- the packages that `playwright install-deps chromium` installs on Ubuntu 24.04,
  listed one by one in the Dockerfile. The build then asks Playwright itself
  (`install-deps --dry-run chromium`, which simulates the installation with apt)
  and fails if anything is missing, and checks with `ldd` that both browser
  executables find every library;
- the browser of Playwright `PLAYWRIGHT_VERSION` (build argument, default in the
  Dockerfile), in `PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright`. The directory
  belongs to the `runner` user, so a job can add the browser of another
  Playwright version without `sudo`;
- `/opt/ms-playwright/.playwright-version`, the Playwright version the browser
  is for.

Node.js and the Playwright command line used to install the browser stay in a
build stage (`node:<version>-bookworm-slim`, mounted for one `RUN`): they are
not in the image. Workflows keep using `actions/setup-node` and the project's
own Playwright.

A browser is tied to a Playwright version. In a job, compare
`.playwright-version` with the project's Playwright version:

- equal: `npx playwright install chromium` finds the browser and downloads
  nothing, and there is no `apt` at all;
- different: `npx playwright install --no-remove chromium` (no `--with-deps`)
  downloads only the browser into the same directory; the libraries of the
  image usually still fit, and `--no-remove` keeps the image's browser for
  branches still on its version. Rebuild the image with the new
  `PLAYWRIGHT_VERSION` to get back to no download.

To update it, set `PLAYWRIGHT_VERSION` and rebuild. If the build stops at the
dependency check, the new version needs other packages: take the Ubuntu 24.04
list of `install-deps` of that version (`npx playwright install-deps
--dry-run chromium` on Ubuntu 24.04 names the missing ones) and update the
list in the Dockerfile. Dependabot does not follow this version: it is an npm
package of the projects that use the image.

## Deliberately not bundled

Language runtimes and SDKs (Node.js, Java, .NET, Go, Ruby, PHP, Rust), cloud
CLIs (`aws`, `az`, `gcloud`), `kubectl`, `helm` and Terraform are **not** in
the image. They would add gigabytes, age quickly, and every project needs
its own version. Install them with their `setup-*` action
(`actions/setup-node`, `actions/setup-java`, …): the runner's tool cache
lives in the persistent work volume, so a version is downloaded once and
reused by later jobs.

Other browsers and their dependencies (Firefox and WebKit of Playwright,
Puppeteer, Cypress) are not bundled: install them in the job, for example
`npx playwright install --with-deps firefox`. The `runner` user has
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
