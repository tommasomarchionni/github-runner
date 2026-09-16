# Quick start with Docker Compose

```bash
git clone https://github.com/tommasomarchionni/github-runner.git
cd github-runner
cp .env.example .env
# edit .env and set at least GITHUB_PAT and GITHUB_REPOSITORY (or GITHUB_ORG)

docker compose up -d --build
docker compose logs -f github-runner
```

Confirm the runner shows up as **Idle** at:

```text
https://github.com/<owner>/<repo>/settings/actions/runners
```

Then manually trigger the included test workflow: **Actions tab →
"Runner smoke test" → Run workflow**.

## Updating the runner

To update to the latest official runner release:

```bash
# in .env
RUNNER_VERSION=X.Y.Z
```

```bash
docker compose up -d --build
```

The container is rebuilt with the new tarball; the existing registration in
the volume stays valid and is reused (see
[Persistence and self-healing](persistence.md)).

## Stopping and removing

```bash
docker compose down
```

The entrypoint intercepts the stop signal and deregisters the runner from
GitHub before exiting (see [Graceful shutdown](shutdown.md)). The
`github-runner-data` volume is **not** removed by `docker compose down`: to
fully reset the registration, remove it explicitly with
`docker compose down -v`.
