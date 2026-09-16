# Plain Docker (without Compose)

!!! note "Docker not installed yet?"
    See [Platform setup](platform-setup.md) for macOS, Windows (WSL 2), and
    Linux install instructions and OS-specific notes before running the
    commands below.

```bash
docker build -t github-runner:local \
  --build-arg RUNNER_VERSION=2.337.0 \
  -f docker/Dockerfile docker

docker run -d \
  --name github-runner-01 \
  --restart unless-stopped \
  -e GITHUB_PAT="ghp_xxx" \
  -e GITHUB_REPOSITORY="tommasomarchionni/REPOSITORY_NAME" \
  -e RUNNER_NAME="github-runner-01" \
  -e RUNNER_LABELS="ci,linux,x64" \
  -v github-runner-data:/home/runner/actions-runner \
  --stop-timeout 60 \
  github-runner:local
```

`--stop-timeout 60` gives the entrypoint enough time to finish an in-flight
job and deregister the runner cleanly before Docker sends `SIGKILL` (see
[Graceful shutdown](shutdown.md)).

## Inspecting logs

```bash
docker logs -f github-runner-01
```

## Removing

```bash
docker stop github-runner-01
docker rm github-runner-01
# keep the volume to reuse the existing registration next time,
# or remove it to force a brand new registration:
docker volume rm github-runner-data
```
