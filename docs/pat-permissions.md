# PAT permissions

This is by far the most common source of problems: if the PAT doesn't have
**exactly** these permissions, registration fails with a `401`/`403` error
that the container prints clearly in its logs (see
[Troubleshooting](troubleshooting.md#401403-when-requesting-a-registration-token)).

The required permission **depends on the scope** you choose (a single
repository or an entire organization) and is officially documented by
GitHub for the endpoints used by this runner (`registration-token` and
`remove-token`): [GitHub REST API — Self-hosted runners](https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28).

## Quick checklist

| Your situation | Token type | Permission to grant |
|---|---|---|
| One private/public repository, personal use | Fine-grained PAT (recommended) | Repository access → that one repo → **Administration: Read and write** |
| One repository, simplest possible setup | Classic PAT | Scope **`repo`** |
| Shared across every repository in an organization | Fine-grained PAT (recommended) | Organization permissions → **Self-hosted runners: Read and write** |
| Shared across an organization, simplest possible setup | Classic PAT | Scope **`admin:org`** |

If you're not sure which row applies to you, use the first one — a single
repository scoped to itself is the smallest possible blast radius for a
first deployment.

## Creating a fine-grained PAT for ONE repository

`GITHUB_REPOSITORY=owner/repo`

1. Go to <https://github.com/settings/personal-access-tokens/new> (or
   navigate manually: profile picture → **Settings** → **Developer
   settings** → **Personal access tokens** → **Fine-grained tokens** →
   **Generate new token**).
2. **Token name**: something identifiable, e.g. `github-runner-<repo>`.
3. **Expiration**: set a real date (see [Rotation](#rotation-and-expiration)
   below) — never "no expiration" for a token this powerful.
4. **Resource owner**: your personal account (or the organization that
   owns the target repository, if applicable).
5. **Repository access**: choose **Only select repositories** and pick the
   target repository — never "All repositories" for a repo-scoped token,
   even though the permission below is already broad; keeping the
   repository list narrow limits what a leaked token could reach.
6. **Permissions → Repository permissions**: find **Administration** and
   set it to **Read and write**.
7. Click **Generate token** and copy it immediately — GitHub shows it only
   once. Paste it into `GITHUB_PAT` in your `.env` file or Dokploy's
   Environment tab.

!!! warning "The Administration permission is broad"
    On a fine-grained PAT, "Administration" also covers other
    administrative operations on the repository (settings, webhooks,
    rulesets, ...), not just runner management — this is a GitHub API
    limitation, not something this project can narrow further. If your
    repository is public and you want the minimum footprint, the
    repository-scoping in step 5 above is what actually limits the blast
    radius, since the permission itself can't be made narrower.

!!! note "You'll also see a \"Metadata: Read-only\" permission appear"
    GitHub's UI automatically adds **Metadata: Read-only** to the token
    the moment you select any other repository permission, and you cannot
    remove it. This is expected and required — Metadata read access is the
    baseline permission GitHub's API requires just to identify and resolve
    the repository itself, before any other permission can be evaluated.
    You don't need to do anything about it beyond leaving it checked.

## Creating a fine-grained PAT for an ORGANIZATION

`GITHUB_ORG=my-org`

1. Same starting point: <https://github.com/settings/personal-access-tokens/new>.
2. **Resource owner**: select the organization. If the organization
   requires approval for fine-grained tokens, you'll be prompted for a
   justification — this is an organization-level policy, not something
   this project controls.
3. **Repository access**: for an organization-level runner you typically
   don't need per-repository access at all — the **Self-hosted runners**
   permission below operates at the organization level regardless. If
   your organization requires selecting at least one repository, pick
   any single repository you have access to; it has no bearing on which
   repositories can use the resulting runner.
4. **Permissions → Organization permissions**: find **Self-hosted
   runners** and set it to **Read and write**.
5. Generate, copy, and set it as `GITHUB_PAT`.

`admin:org` on a classic PAT is very broad (full organization
administration): for an organization-level runner, always prefer the
fine-grained PAT above, scoped to just the "Self-hosted runners"
permission, which is far more limited in what it can do if leaked.

## Classic PAT (simpler, broader)

If you'd rather not deal with fine-grained scoping, a classic PAT works
too, at the cost of much broader access:

1. Go to <https://github.com/settings/tokens/new>.
2. **Note**: something identifiable.
3. **Expiration**: set a real date.
4. **Select scopes**:
      - Repository-scoped runner → check **`repo`** (full control of
        private repositories — there is no narrower classic scope for
        runner registration).
      - Organization-scoped runner → check **`admin:org`**, and also
        `repo` if any of the repositories that will use the runner are
        private.
5. Generate and copy the token.

## Rotation and expiration

- Always set an expiration date (GitHub allows up to 1 year; 90 days is a
  reasonable production default) and note it down for rotation — the
  container has no way to know a PAT has expired ahead of time. The next
  API call simply fails, and the entrypoint handles that failure
  gracefully rather than crash-looping forever (see
  [Persistence and self-healing](persistence.md)), but the runner does go
  offline until you supply a fresh token.
- To rotate: generate a new PAT with the same permissions, update
  `GITHUB_PAT` in `.env` (or Dokploy's Environment tab), and redeploy. The
  existing runner registration in the persistent volume is unaffected —
  only the credential used to talk to the GitHub API changes.

## Verifying a token manually

Before wiring a new PAT into the container, you can confirm it has the
right permission with a single `curl` call (replace `TOKEN` and
`owner/repo`):

```bash
curl -sS -X POST \
  -H "Authorization: Bearer TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/owner/repo/actions/runners/registration-token
```

A JSON object containing a `token` field means the permission is correct.
A `401`/`403` response means the PAT is missing the permission described
above for your chosen scope.
