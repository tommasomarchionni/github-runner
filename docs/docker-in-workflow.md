# Docker inside workflows

The Docker CLI (client only, no daemon) is **bundled in the prebuilt GHCR
image by default** — together with the standard runner-side base tools
already baked into the image, including `iproute2` (`ip`). You do not
need to rebuild the image or set any build argument.

To let the runner talk to a Docker daemon, simply mount the host socket:

```yaml
# docker-compose.yml or docker-compose.prebuilt.yml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

That's all. Uncomment that line, recreate the container, and your
workflows can run `docker build`, `docker compose`, `docker run`, etc.

> **Security note** — mounting `/var/run/docker.sock` grants the runner
> **full access to the host's Docker daemon**, which is effectively
> equivalent to root on the host. Only do this on runners that execute
> jobs from trusted sources, and **never** on runners that process
> untrusted external pull requests.

## Opting out of the bundled CLI

If you want a smaller image without the Docker CLI (e.g. to reduce
attack surface on a runner that will never use Docker), rebuild locally
with `INSTALL_DOCKER_CLI=false`:

```bash
# .env
INSTALL_DOCKER_CLI=false
docker compose build
```

The prebuilt GHCR image always includes the CLI.

## Safer alternative (Docker-in-Docker)

If you only need to build and test containers without touching the
host's existing images or network, consider Docker-in-Docker
(`docker:dind` as a sidecar) instead of mounting the host socket. This
keeps the runner's Docker environment fully isolated from the host, at
the cost of extra setup and resource usage. This repository does not
ship a DinD sidecar by default, but you can add one to
`docker-compose.yml` if your workflows need it.
