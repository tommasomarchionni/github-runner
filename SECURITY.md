# Security Policy

## Supported versions

Only the latest published image tag (`latest`/`edge`) and the most recent
tagged release receive security fixes. Please always run the latest
version before reporting an issue.

## Reporting a vulnerability

If you discover a security vulnerability (for example: PAT/token leakage,
a way to bypass the deregistration flow, container privilege escalation,
or a dependency with a known CVE affecting this image), please **do not**
open a public issue.

Instead, use GitHub's private reporting flow for this repository:

1. Go to the **Security** tab of
   [github.com/tommasomarchionni/github-runner](https://github.com/tommasomarchionni/github-runner/security).
2. Click **"Report a vulnerability"** to open a private advisory.

You should expect an initial response within a few days. Once a fix is
available, a new image will be published to GHCR and a GitHub Security
Advisory will be issued, crediting the reporter unless anonymity is
requested.

## Scope and known trade-offs

A few points are inherent to how self-hosted runners work and are not
considered vulnerabilities in themselves, but you should be aware of them:

- **The PAT is a powerful credential.** Anyone with access to the running
  container's environment (e.g. `docker exec`, host root access) can read
  it. Scope the PAT as narrowly as possible — see
  [PAT permissions](docs/pat-permissions.md) — and treat the host running
  the container as a trusted machine.
- **`runs-on: self-hosted` on a public repository is dangerous by
  default.** Anyone who can open a pull request can potentially run
  arbitrary code on your runner unless you require approval for first-time
  contributors (GitHub Settings → Actions → "Fork pull request workflows
  from outside collaborators") and/or use
  [ephemeral runners](docs/ephemeral.md).
- **Mounting the Docker socket** (see
  [Docker inside workflows](docs/docker-in-workflow.md)) grants the runner
  root-equivalent access to the host. Only enable this for trusted
  workflows.

## Dependencies

Base image and GitHub Actions dependencies are kept up to date
automatically via [Dependabot](.github/dependabot.yml), and every image
build is scanned implicitly through `hadolint` in CI (see
[Testing and CI](docs/testing.md)).
