# Persistence and self-healing

The named volume `github-runner-data` is mounted at
`/home/runner/actions-runner` and holds:

- `.runner` / `.credentials`: the runner's registration (no need to
  re-register on every restart, except in ephemeral mode);
- `_work/`: the job working directory, also useful for local caches across
  runs.

Removing the volume forces a brand new registration on the next start (the
entrypoint detects this on its own because `.runner` is missing).

## What happens in each restart/recreate scenario

This is the part that matters most in production: **the runner must be
able to re-authenticate correctly every time the container is destroyed and
restarted**, without any manual step.

| Scenario | Volume | Local registration | What happens |
|---|---|---|---|
| Simple restart (`docker restart`, host reboot) | kept | valid | The entrypoint finds `.runner`/`.credentials`, skips `config.sh`, and starts `run.sh` directly. Fast, no API calls. |
| Container destroyed and recreated (redeploy, `docker compose up` again, Dokploy redeploy) with the **same** volume | kept | valid | Same as above: the existing registration is reused as-is. |
| Container destroyed and recreated, but the registration is **stale** (runner removed manually from the GitHub UI, credentials copied from another host, GitHub-side state out of sync) | kept | invalid | `run.sh` fails almost immediately. The entrypoint detects a fast failure (see "Self-healing" below), wipes the local state, and re-registers using a fresh token minted from `GITHUB_PAT`. No manual intervention needed. |
| Volume removed/reset (`docker compose down -v`, fresh deploy target) | removed | none | `.runner` is missing, so the entrypoint registers from scratch using the PAT, exactly like a first-time deploy. |
| `RUNNER_EPHEMERAL=true` | kept or removed | irrelevant | The entrypoint always wipes any local state before registering: every run starts from a clean registration and is removed by GitHub itself once the job finishes. |
| `RUNNER_FORCE_RECONFIGURE=true` | kept | irrelevant | Local state is wiped and a fresh registration is created on the next start, regardless of whether the existing one looked valid. Useful for manual troubleshooting; set it back to `false` afterwards. |

## Self-healing logic

On every start, the entrypoint runs a bounded retry loop
(`RUNNER_START_MAX_ATTEMPTS`, default `3`):

1. If a registration already exists in the volume, it's reused; otherwise a
   new one is created via the GitHub API using `GITHUB_PAT`.
2. `run.sh` is started and its running time is measured.
3. If `run.sh` exits with a non-zero code **within
   `RUNNER_STARTUP_GRACE_SECONDS` seconds** (default `20`) of starting,
   that's treated as a strong signal that the stored registration is
   broken (rather than a job failing mid-run) — a legitimate job failure
   happens well after startup, not in the first few seconds.
4. In that case, the entrypoint best-effort deregisters the stale entry,
   deletes `.runner`/`.credentials` from the volume, waits a short
   backoff, and tries again with a brand-new registration.
5. If the runner keeps failing fast after `RUNNER_START_MAX_ATTEMPTS`
   attempts, the container exits with a non-zero code so your orchestrator
   (Docker's `restart` policy, Dokploy, Swarm, ...) can apply its own
   backoff instead of the entrypoint looping forever internally.

This means that even if you (or GitHub) invalidate a runner's registration
out-of-band, the very next container start will notice, clean up, and
re-authenticate correctly on its own — without you having to touch the
volume or generate anything by hand.

## Tuning

- `RUNNER_STARTUP_GRACE_SECONDS`: increase it if your environment is slow
  to establish the first connection (e.g. a congested network) and you see
  false-positive re-registrations for otherwise healthy runners.
- `RUNNER_START_MAX_ATTEMPTS`: increase it if registrations can be flaky
  during rollouts (e.g. GitHub API rate limiting) and you'd rather retry a
  few more times before giving up.
