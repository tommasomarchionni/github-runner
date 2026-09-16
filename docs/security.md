# Security

The full security policy and vulnerability reporting process live in
[`SECURITY.md`](https://github.com/tommasomarchionni/github-runner/blob/main/SECURITY.md)
at the repository root. This page summarizes the operational
recommendations for running this image safely.

## PAT handling

- The PAT is only ever passed as an environment variable to the container
  and used on the fly for GitHub API calls — it is **never written to
  disk**.
- Scope it as narrowly as possible: see
  [PAT permissions](pat-permissions.md).
- Set an expiration date and rotate it; treat the PAT like any other
  production secret (secret manager, Dokploy's protected env vars, GitHub
  Actions secrets — never a plain committed file).
- Anyone with shell access to the running container (`docker exec`) or
  root access to the host can read the PAT from the process environment.
  Treat the host as trusted.

## Public repositories and untrusted contributions

`runs-on: self-hosted` on a public repository can let anyone who opens a
pull request run arbitrary code on your machine, unless you:

- Require approval for workflows from first-time or outside contributors
  (repository **Settings → Actions → General → Fork pull request
  workflows from outside collaborators**).
- Use [ephemeral runners](ephemeral.md) so every job starts from a clean,
  disposable environment.
- Avoid mounting the Docker socket (see
  [Docker inside workflows](docker-in-workflow.md)) unless strictly
  necessary.

## Non-root by default

The container runs as an unprivileged `runner` user (uid 1001) with
passwordless `sudo` available only for the runner's own setup scripts, not
as a general-purpose root shell.

## Keeping dependencies current

Base image versions and GitHub Actions used in the CI/CD workflows are
kept up to date automatically via
[Dependabot](https://github.com/tommasomarchionni/github-runner/blob/main/.github/dependabot.yml).
`hadolint` runs in CI on every change to catch common Dockerfile
anti-patterns (see [Testing and CI](testing.md)).
