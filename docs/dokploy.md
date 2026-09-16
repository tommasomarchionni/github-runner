# Configuring on Dokploy

This project also works as a **Docker Compose** application inside
Dokploy, reusing the same `docker-compose.yml` from this repository.

!!! tip "Prefer the prebuilt image"
    For the simplest Dokploy setup, use `docker-compose.prebuilt.yml`
    instead of `docker-compose.yml` — it pulls the ready-made image from
    GHCR instead of building it, so Dokploy doesn't need a Dockerfile
    build context at all. See [Prebuilt image](prebuilt-image.md).

1. In Dokploy, create a new **Compose** application.
2. As the source, connect this Git repository (Dokploy can build directly
   from the `docker-compose.yml` at the repository root) or paste the
   contents of `docker-compose.yml` into Dokploy's Compose editor.
3. In the application's **Environment** section, set the variables that
   match `.env.example`, at minimum:

   ```env
   GITHUB_PAT=ghp_xxx or github_pat_xxx
   GITHUB_REPOSITORY=tommasomarchionni/REPOSITORY_NAME
   RUNNER_NAME=dokploy-github-runner-01
   RUNNER_LABELS=ci,linux,x64,dokploy
   ```

   Mark `GITHUB_PAT` as a **secret/protected** variable if Dokploy's UI
   offers that distinction, so it never shows up in plaintext deploy logs.

4. **Networking**: this application does not need Dokploy's managed
   network (`dokploy-network`) or Traefik, because the runner exposes no
   inbound HTTP port — it only makes outbound connections to
   `github.com`/`api.github.com`. Leave the `runner-network` defined in the
   Compose file as-is (isolated), and attach other networks **only** if a
   workflow genuinely needs to reach an internal service (e.g. a test
   database also running on Dokploy).
5. **Persistent volume**: make sure Dokploy keeps the
   `github-runner-data` volume (declared in the Compose file) across
   redeploys, so the runner's registration survives app restarts without
   needing to be regenerated. See
   [Persistence and self-healing](persistence.md) for exactly what happens
   in each restart/recreate scenario.
6. **Resources**: tune `RUNNER_MEM_LIMIT` and `RUNNER_CPUS` to match the
   real capacity of your Dokploy host (especially if it's a Proxmox LXC
   with limited RAM) to avoid a heavy job triggering an OOM-kill on the
   host.
7. Click **Deploy**. In the application's logs you should see:

   ```text
   [entrypoint] Registering runner '...' (scope=repo, group=Default, labels=ci,linux,x64,dokploy, ephemeral=false)
   [entrypoint] Starting runner (attempt 1/3)...
   ```

8. If you later move Dokploy, update the image, or recreate the container,
   **no manual action is needed**: on startup the entrypoint fetches a new
   registration token on the fly using the same `GITHUB_PAT`, and if the
   old registration in the volume turns out to be invalid it re-registers
   itself automatically (self-healing, see
   [Persistence and self-healing](persistence.md)).

!!! note "Compared to a temporary-token setup"
    Unlike a setup based on an image that requires pasting a temporary
    registration token from the GitHub UI by hand, there is **no one-hour
    window** to complete the deploy here: the PAT stays valid until you
    revoke it or it reaches the expiration date you set.
