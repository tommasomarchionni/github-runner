# Docker inside workflows

If a workflow needs to run `docker build`/`docker compose`/test containers:

1. Rebuild the image with `INSTALL_DOCKER_CLI=true` (adds only the Docker
   client, not a daemon).
2. In `docker-compose.yml`, uncomment:

   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   ```

This grants the runner **full access to the host's Docker daemon**
(equivalent to root on the host). Only do this if you truly need it, and
**never** on a runner that executes jobs from untrusted external pull
requests.

## Safer alternative

If you only need to build and test containers without needing the host's
existing images/network, consider Docker-in-Docker (`docker:dind` as a
sidecar) instead of mounting the host socket. This keeps the runner's
Docker environment isolated from the host, at the cost of extra setup and
resource usage. This repository does not ship a DinD sidecar by default,
but you can add one to `docker-compose.yml` if your workflows need it.
