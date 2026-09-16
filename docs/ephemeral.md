# Ephemeral runners

With `RUNNER_EPHEMERAL=true`:

- the container wipes any leftover registration before registering (it
  never reuses a previous state);
- the runner executes **exactly one job** and then deregisters itself from
  GitHub;
- the entrypoint exits as a result: pair this mode with `restart:
  unless-stopped` (or `always`) in Compose, so Docker recreates the
  container and registers a fresh one ready for the next job.

This is the safest choice for public repositories or CI that runs
untrusted code (every job starts from a clean environment).

```env
RUNNER_EPHEMERAL=true
```

```yaml
services:
  github-runner:
    restart: unless-stopped
    # ...
```
