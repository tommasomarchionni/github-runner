# Testing and CI

## Run everything locally

```bash
./tests/run-tests.sh
```

This runs, entirely inside Docker (nothing to install on your machine):

1. **[Shellcheck](https://www.shellcheck.net/)** on `docker/entrypoint.sh`
   — static analysis for common shell scripting mistakes.
2. **[Hadolint](https://github.com/hadolint/hadolint)** on
   `docker/Dockerfile` — Dockerfile best-practice linting.
3. **[Bats](https://github.com/bats-core/bats-core)** unit tests
   (`tests/test_entrypoint.bats`) — exercise the entrypoint's pure
   functions (`resolve_scope`, `api_scope_path`, `config_url`,
   `build_labels_arg`, self-healing defaults, ...) without starting a real
   runner or contacting the GitHub API.
   A second suite (`tests/test_base_image.bats`) reads the repository files
   and checks that the Dockerfile builds on an Ubuntu LTS and that Dependabot
   ignores major and minor bumps of the base image (see
   [Base image](bundled-tools.md#base-image-ubuntu-lts)).
4. A full **image build** (`docker build`), catching any Dockerfile
   regression.
5. A **strict docs build** (`mkdocs build --strict`), catching broken
   internal links or missing pages before they reach GitHub Pages.

## Continuous integration

Every push to `main` and every pull request triggers
[`.github/workflows/ci.yml`](https://github.com/tommasomarchionni/github-runner/blob/main/.github/workflows/ci.yml),
which runs shellcheck, hadolint, the bats suite, and a Docker build (with
smoke checks that the container fails with a clear message when
`GITHUB_PAT` is missing and that bundled tools such as the Docker CLI and
`iproute2` are present) as separate parallel/sequential jobs. All of this
runs on GitHub-hosted runners, and GitHub Actions minutes are free and
unlimited for public repositories.

## Image publishing

[`.github/workflows/publish-image.yml`](https://github.com/tommasomarchionni/github-runner/blob/main/.github/workflows/publish-image.yml)
builds and pushes the multi-arch image to GHCR on every push to `main` and
on tagged releases — see [Prebuilt image](prebuilt-image.md).

## Bundled tools test

[`tests/test_image_tools.sh`](https://github.com/tommasomarchionni/github-runner/blob/main/tests/test_image_tools.sh)
runs inside a built image, as the unprivileged `runner` user, and checks
that every bundled tool is there and works (a zip round trip, zstd and xz
archives, a Python virtual environment, a compiled C program):

```bash
tests/test_image_tools.sh github-runner:test full   # default build arguments
tests/test_image_tools.sh github-runner:test-slim slim   # INSTALL_BUILD_TOOLS=false
```

`slim` also asserts that the toolchain and Python are **not** in the image,
so the build argument is proven to work in both directions. `run-tests.sh`
and CI build and check both variants.

## End-to-end smoke test

[`.github/workflows/smoke-test.yml`](https://github.com/tommasomarchionni/github-runner/blob/main/.github/workflows/smoke-test.yml)
is a manually triggered workflow you can run against your **own** live
runner after deploying it, to confirm it registered correctly and can
actually execute a job (checks out the repo, prints environment info,
verifies base tools including `ip`, the Docker CLI and the GitHub CLI,
writes to the persistent work directory).

## Documentation

[`.github/workflows/docs.yml`](https://github.com/tommasomarchionni/github-runner/blob/main/.github/workflows/docs.yml)
builds this MkDocs Material site and deploys it to GitHub Pages on every
change under `docs/` or `mkdocs.yml`. Preview it locally with:

```bash
pip install -r docs/requirements.txt
mkdocs serve
```
