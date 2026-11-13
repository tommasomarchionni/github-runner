# GitHub CLI inside workflows

The GitHub CLI (`gh`) is **bundled in the image by default**, as it is on
GitHub-hosted runners. Workflows can call the GitHub API, comment on pull
requests, merge them or manage labels without installing anything at
every run.

## Using it in a workflow

`gh` needs a token in `GH_TOKEN`. The token of the workflow is usually
enough; grant it only the permissions the job needs:

```yaml
jobs:
  comment:
    runs-on: [self-hosted, linux, x64]
    permissions:
      pull-requests: write
    steps:
      - name: Comment on the pull request
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh pr comment "${{ github.event.pull_request.number }}" --repo "${{ github.repository }}" --body "Checked."
```

Outside a checkout, pass `--repo` (or set `GH_REPO`): `gh` cannot infer the
repository from the working directory.

!!! note
    The runner's own `GITHUB_PAT` (used only to register the runner) is
    never exposed to jobs. `gh` uses the token you pass in `GH_TOKEN`.

## Building without it

For a smaller image, build from source with the CLI disabled:

```dotenv
# .env
INSTALL_GH_CLI=false
```

```bash
docker compose build --build-arg INSTALL_GH_CLI=false
```

The prebuilt GHCR image always includes it.

## Updating a running runner

A runner keeps the image it was created with. To get a new image:

- **Docker Compose (prebuilt):** `docker compose -f docker-compose.prebuilt.yml pull`
  and then `docker compose -f docker-compose.prebuilt.yml up -d`.
- **Dokploy:** set the image tag (`latest`, or a pinned `sha-<short-sha>`
  or `vX.Y.Z`, see [Prebuilt image](prebuilt-image.md)) and redeploy the
  service. With `latest`, redeploying pulls the newest image.

The named volume with the runner registration is kept, so the runner comes
back with the same name and labels. Verify with the
[smoke test](testing.md#end-to-end-smoke-test).
