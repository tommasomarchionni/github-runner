# Graceful shutdown

When Docker sends `SIGTERM` (`docker stop`, `docker compose down`, a
Dokploy redeploy, a Swarm/Kubernetes rolling update, ...), the entrypoint:

1. Stops accepting new jobs and waits for `run.sh` to finish, up to
   `RUNNER_UNREGISTER_TIMEOUT` seconds (default `30`).
2. Requests a fresh **removal token** from the GitHub API using
   `GITHUB_PAT`.
3. Runs `config.sh remove` with that token, so the runner disappears from
   **Settings → Actions → Runners** instead of lingering as "Offline".
4. Exits with the same status code `run.sh` returned (or `0` on a clean
   stop).

`stop_grace_period: 60s` in `docker-compose.yml` gives Docker enough time
to wait for this sequence before escalating to `SIGKILL`. If you lower it
below `RUNNER_UNREGISTER_TIMEOUT`, an in-flight job might get killed
mid-way and the runner may not deregister cleanly (it will still be
cleaned up automatically on the *next* start, per
[Persistence and self-healing](persistence.md), but you'll see a stale
"Offline" entry in the meantime).

## Why this matters

Without explicit deregistration, a destroyed container leaves a runner
stuck as "Offline" in the repository/organization settings forever (GitHub
does not automatically prune it). Over time this clutters the runners list
and can be confusing when debugging which runner actually picked up a job.
