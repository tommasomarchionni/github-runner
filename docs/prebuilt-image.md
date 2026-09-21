# Prebuilt image (GHCR)

Every push to `main` and every tagged release automatically builds and
publishes a **multi-arch** (`linux/amd64`, `linux/arm64`) image to GitHub
Container Registry via
[`.github/workflows/publish-image.yml`](https://github.com/tommasomarchionni/github-runner/blob/main/.github/workflows/publish-image.yml).

```text
ghcr.io/tommasomarchionni/github-runner
```

Available tags:

| Tag | When it's updated |
|---|---|
| `latest` | every push to `main` |
| `edge` | same as `latest`, explicit alias |
| `vX.Y.Z`, `X.Y`, `X` | on a pushed git tag `vX.Y.Z` |
| `sha-<short-sha>` | every build, for exact reproducibility |

The image is public and requires no authentication to pull. The Docker
CLI (client only) is **included by default** — see
[Docker inside workflows](docker-in-workflow.md) to enable it with a
single socket mount.

## Using it with Docker Compose

Use `docker-compose.prebuilt.yml` instead of `docker-compose.yml` — same
environment variables, no local build step:

```bash
cp .env.example .env
# edit .env
docker compose -f docker-compose.prebuilt.yml up -d
```

## Using it with Dokploy

Paste `docker-compose.prebuilt.yml` directly in Dokploy's Compose editor
(no repository build context needed) — see
[Configuring on Dokploy](dokploy.md) for the full walkthrough.

## Using it with plain Docker

```bash
docker run -d \
  --name github-runner-01 \
  --restart unless-stopped \
  -e GITHUB_PAT="ghp_xxx" \
  -e GITHUB_REPOSITORY="tommasomarchionni/REPOSITORY_NAME" \
  -v github-runner-data:/home/runner/actions-runner \
  --stop-timeout 60 \
  ghcr.io/tommasomarchionni/github-runner:latest
```

## Pinning a version

For production, pin an explicit tag (`vX.Y.Z` or `sha-<short-sha>`) instead
of `latest`, so an upstream update to this project doesn't silently change
your runner:

```env
RUNNER_IMAGE_TAG=v1.2.0
```

## Building it yourself instead

If you need a custom modification (extra packages baked into the image,
a different `RUNNER_VERSION` pin, etc.), use the local-build
`docker-compose.yml` described in
[Quick start with Docker Compose](docker-compose-guide.md) instead of the
prebuilt image.
