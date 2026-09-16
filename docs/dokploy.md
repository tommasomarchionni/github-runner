# Configuring on Dokploy

[Dokploy](https://dokploy.com/) is a self-hosted PaaS that runs on a Linux
host you control and already includes Docker — you don't install anything
on your own machine for this path, only inside Dokploy's web UI. This page
covers every way to run this runner on Dokploy, in the order most people
should try them.

!!! tip "Recommended path"
    Use a **Compose service** with `docker-compose.prebuilt.yml`. It reuses
    this repository's tested Compose file as-is, needs no Dockerfile build
    context on your Dokploy host, and deploys in seconds by pulling the
    image from GHCR. The other modes below are documented for completeness
    and for cases where the default doesn't fit your setup.

## Choosing a service type

Dokploy has two service types that can both run this container. They are
not interchangeable in how environment variables and volumes behave, which
is the single most common source of confusion — read this table before
picking one.

| | **Compose service** (recommended) | **Application service** (Docker/Dockerfile) |
|---|---|---|
| What it deploys | This repo's `docker-compose.yml` / `docker-compose.prebuilt.yml` as-is | A single container built from `docker/Dockerfile`, or pulled directly from `ghcr.io/tommasomarchionni/github-runner` |
| Environment variables | Written to a `.env` file next to the compose file; **only reach the container if the compose file references them** (this repo's compose files already do — see below) | Passed **directly** as container environment variables, no extra step |
| Persistent volume | Declared in the compose file itself (`github-runner-data`) | Configured in the service's own **Volumes** tab |
| Best for | Matching this repo's tested setup exactly, least configuration drift | Environments where you don't want Dokploy to read a `docker-compose.yml` at all, or prefer per-field UI configuration |

Both are fully supported; **Compose is the path this documentation assumes
by default** because it's what's tested in this repository's own CI.

## Mode A — Compose, prebuilt image (recommended)

No build step on your Dokploy host at all — Dokploy just pulls
`ghcr.io/tommasomarchionni/github-runner` and starts it.

1. In Dokploy, create a **Project** (or open an existing one) to group this
   service with others.
2. Inside the project, **Create Service → Compose**.
3. Set **Compose Type** to `Docker Compose` (not `Stack` — Stack targets
   Docker Swarm and isn't needed for a single container; it also doesn't
   support the `build:` key, which is irrelevant here anyway since this
   mode uses a prebuilt image).
4. In the **General** tab, choose how Dokploy gets the compose file:
     - **Git-based**: select provider `GitHub` (or `Git` for a generic
       URL), point it at
       `https://github.com/tommasomarchionni/github-runner`, branch
       `main`, and set **Compose Path** to `./docker-compose.prebuilt.yml`.
     - **Raw editor**: skip connecting a repository entirely and paste the
       contents of
       [`docker-compose.prebuilt.yml`](https://github.com/tommasomarchionni/github-runner/blob/main/docker-compose.prebuilt.yml)
       directly into Dokploy's built-in Compose editor. Use this if you'd
       rather not grant Dokploy access to the repository, or want to tweak
       the file inline.
5. Open the **Environment** tab (keyboard shortcut `g` then `e`) and set,
   at minimum:

   ```env
   GITHUB_PAT=ghp_xxx or github_pat_xxx
   GITHUB_REPOSITORY=tommasomarchionni/REPOSITORY_NAME
   RUNNER_NAME=dokploy-github-runner-01
   RUNNER_LABELS=ci,linux,x64,dokploy
   ```

   See the full [Environment variables](environment-variables.md) reference
   for every other option (organization scope, ephemeral mode, GitHub
   Enterprise Server, self-healing tuning, ...).

   !!! warning "Does Dokploy actually pass these into the container?"
       Yes, for this repository specifically — but only because
       `docker-compose.prebuilt.yml` (and `docker-compose.yml`) already
       reference every variable with `${VAR_NAME}` syntax inside their
       `environment:` block, for example
       `GITHUB_PAT: ${GITHUB_PAT:?Set GITHUB_PAT in your .env file}`.
       [Dokploy's own documentation](https://docs.dokploy.com/docs/core/docker-compose)
       is explicit that variables typed into the Environment tab are
       written to a `.env` file next to the compose file but are **not**
       automatically injected into containers — they only reach the
       container if the compose file uses `${VAR_NAME}` interpolation (as
       this repo's files do) or declares `env_file: .env`. If you ever
       write your **own** compose file from scratch for a different
       project, remember to add one of those two mechanisms yourself, or
       your variables will silently stay in the `.env` file and never
       reach the container.

   Mark `GITHUB_PAT` as a **secret/protected** variable if your Dokploy
   version offers that distinction, so it never shows up in plaintext
   deploy logs.

6. **Domains tab**: leave empty. This container makes only outbound
   connections to `github.com`/`api.github.com` — it exposes no inbound
   HTTP port, so there is nothing to assign a domain to (unlike a typical
   web app deployed on Dokploy).
7. **Volumes**: nothing to configure here — the persistent volume
   (`github-runner-data`, mounted at `/home/runner/actions-runner`) is
   already declared inside the compose file itself and Dokploy respects it
   automatically. See [Persistence and self-healing](persistence.md) for
   exactly what that volume protects across redeploys.
8. **Advanced tab**: two things worth checking here:
     - **Resources** (CPU/memory): if your Dokploy version exposes CPU/
       memory sliders here, they are enforced by Dokploy independently of
       the compose file's own `mem_limit`/`cpus` keys. Set both consistent
       with each other, and with the real capacity of your host — this
       matters most on a resource-constrained target such as a small VPS
       or a Proxmox LXC container, where an unbounded runner can trigger a
       host-level OOM kill during a heavy job.
     - **Networking**: leave the compose file's own `runner-network`
       (isolated, `bridge` driver) as-is. Attach Dokploy's shared
       `dokploy-network` only if a workflow genuinely needs to reach
       another service running on the same Dokploy host (for example, a
       test database used by your CI jobs) — this runner does not need it
       by default.
9. Click **Deploy**. In the service's **Logs** tab you should see:

   ```text
   [entrypoint] Registering runner '...' (scope=repo, group=Default, labels=ci,linux,x64,dokploy, ephemeral=false)
   [entrypoint] Starting runner (attempt 1/3)...
   ```

   If the deploy reports success but the runner never appears at
   **Settings → Actions → Runners** on GitHub, the logs are the first
   place to check — see
   [Troubleshooting](troubleshooting.md#dokploy-deploy-succeeds-but-the-runner-never-appears-in-github).

10. Optional: the **Volume Backups** tab lets Dokploy snapshot the
    `github-runner-data` volume on a schedule. This isn't critical (the
    runner self-heals and re-registers from `GITHUB_PAT` even if the
    volume is lost, see [Persistence and self-healing](persistence.md)),
    but it does save you the ~30 seconds of a fresh registration after a
    host-level incident.

## Mode B — Compose, build from source

Same as Mode A, except:

- Set **Compose Path** to `./docker-compose.yml` instead of the prebuilt
  variant.
- Dokploy builds the image on your host on every deploy using
  `docker/Dockerfile`, instead of pulling from GHCR. This is slower per
  deploy but useful if you've forked the repository and modified the
  Dockerfile (extra packages, a different base image, `INSTALL_DOCKER_CLI`
  baked in, etc.) and want Dokploy to always build your exact fork rather
  than depending on the upstream GHCR image.
- Everything else (Environment, Domains, Volumes, Advanced) is identical
  to Mode A.

## Mode C — Application service (Docker/Dockerfile), no Compose

Use this if you specifically want Dokploy to manage the container as a
plain **Application** rather than reading a compose file — for example, if
your Dokploy workflow standardizes on Application services for every
non-multi-container workload.

1. **Create Service → Application**.
2. In the **General** tab, choose the source:
     - **From the prebuilt image**: provider `Docker`, image
       `ghcr.io/tommasomarchionni/github-runner:latest` (or a pinned
       `vX.Y.Z`/`sha-<short-sha>` tag, see [Prebuilt image](prebuilt-image.md#pinning-a-version)).
     - **Building from source**: provider `GitHub`/`Git` pointing at this
       repository, Build Type `Dockerfile`, Docker context `./docker`,
       Dockerfile path `docker/Dockerfile`.
3. In the **Environment** tab, set the same variables as in Mode A. Unlike
   Compose, **Application services pass Environment-tab variables directly
   into the container** — there is no `.env`-file/`${VAR}` interpolation
   step to worry about here.
4. In the **Advanced → Volumes** tab, add a volume mounted at
   `/home/runner/actions-runner` (named, e.g., `github-runner-data`) so the
   registration and work directory survive redeploys — this is the
   Application-service equivalent of the `volumes:` block in the compose
   file, and it is **not automatic** the way it is in Mode A/B; skipping
   this step means every redeploy re-registers from scratch.
5. Leave **Domains** and **Ports** unset — no inbound traffic is needed.
6. **Advanced → Resources**: same CPU/memory guidance as Mode A.
7. Deploy and check the **Logs** tab for the same
   `[entrypoint] Registering runner ...` line as above.

Field names in Dokploy's Application UI can vary slightly between
versions; the sequence above (source → environment → persistent volume →
skip networking → deploy) holds regardless of exact label wording.

## Redeploys and restarts: what to expect

Whichever mode you use, see
[Persistence and self-healing](persistence.md) for the full breakdown, but
in short: **no manual action is ever needed** after the first deploy.
Redeploying, updating the image tag, or Dokploy recreating the container
for any reason all reuse the existing registration from the persistent
volume; if that registration is ever stale, the entrypoint detects it and
re-registers automatically using the same `GITHUB_PAT`.

!!! note "Compared to a temporary-token setup"
    Unlike a setup based on an image that requires pasting a temporary
    registration token from the GitHub UI by hand, there is **no one-hour
    window** to complete the deploy here: the PAT stays valid until you
    revoke it or it reaches the expiration date you set in
    [PAT permissions](pat-permissions.md).
