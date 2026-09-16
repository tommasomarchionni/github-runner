# Troubleshooting

## `GITHUB_PAT is required`

The container exits immediately. `GITHUB_PAT` is missing or empty in your
environment/`.env` file. Check `docker compose config` to confirm the
variable is actually being passed through.

## `401`/`403` when requesting a registration token

The PAT lacks the right permission for the scope you configured. See
[PAT permissions](pat-permissions.md) — the most common mistake is using a
fine-grained PAT scoped to "All repositories" with the wrong permission,
or a classic PAT missing `repo`/`admin:org`.

## Runner registers but never picks up jobs

- Check that your workflow's `runs-on` labels **exactly** match
  `RUNNER_LABELS` (all of them, case-sensitive) — see
  [Labels and runner groups](labels-and-groups.md).
- For organization runners, confirm the runner's **group** allows the
  repository that owns the workflow.
- Confirm the runner shows as **Idle**, not **Offline**, in
  **Settings → Actions → Runners**.

## Runner shows "Offline" after a container restart

If the container exits without going through a graceful `SIGTERM` (e.g.
`docker kill`, an abrupt host power-loss), the deregistration step never
runs. On the **next** normal start, the self-healing logic will detect a
fast failure if the stored registration is now stale and re-register
automatically — see [Persistence and self-healing](persistence.md). If it
doesn't recover after a couple of attempts, remove the runner manually
from the GitHub UI and set `RUNNER_FORCE_RECONFIGURE=true` for one restart.

## The container keeps restarting (crash loop)

Check the logs first:

```bash
docker compose logs -f github-runner
```

- If you see repeated `"Starting runner (attempt N/3)..."` followed by a
  fast failure, the self-healing loop is exhausting
  `RUNNER_START_MAX_ATTEMPTS`. This usually means the PAT itself is
  invalid/expired/lacks permission (a genuinely bad credential can't be
  fixed by re-registering) — verify it manually with `curl` against the
  GitHub API endpoint mentioned in the logs.
- Increase `RUNNER_STARTUP_GRACE_SECONDS` if your network is slow and
  legitimate startups are being mistaken for fast failures.

## Building on Apple Silicon / ARM produces an `x64` binary (or fails at runtime)

Make sure `RUNNER_ARCH` is left **empty** in `.env` — the Dockerfile
auto-detects the correct architecture from the build platform
(`TARGETARCH`). Only set `RUNNER_ARCH` explicitly if you need to force a
specific architecture different from your build host's.

## Dokploy deploy succeeds but the runner never appears in GitHub

Open the application's logs in Dokploy directly — Dokploy's deploy status
only reflects whether the container started, not whether the entrypoint
successfully registered with GitHub. Look for the
`[entrypoint] Registering runner ...` line and any error immediately after
it.

## Still stuck?

Open an issue with your (redacted) logs and configuration using the
["Bug report" template](https://github.com/tommasomarchionni/github-runner/issues/new/choose).
