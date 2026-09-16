# PAT permissions

This is by far the most common source of problems: if the PAT doesn't have
**exactly** these permissions, registration fails with a `401`/`403` error
that the container prints clearly in its logs.

The required permission **depends on the scope** you choose (a single
repository or an entire organization) and is officially documented by
GitHub for the endpoints used by this runner (`registration-token` and
`remove-token`): [GitHub REST API — Self-hosted runners](https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28).

## Runner scoped to ONE repository

`GITHUB_REPOSITORY=owner/repo`

| Token type | Required permission |
|---|---|
| **Fine-grained PAT** (recommended) | Repository access limited to the target repo → **Repository permissions → Administration: Read and write** |
| **Classic PAT** | scope **`repo`** (full control of private repositories) |

!!! warning "The Administration permission is broad"
    On a fine-grained PAT, "Administration" also covers other
    administrative operations on the repo, not just runner management. If
    your repository is public and you want the minimum footprint, still
    scope the PAT to that **single repository** (not "All repositories"),
    so the blast radius stays limited even though the permission itself is
    broad.

## Runner shared at the ORGANIZATION level

`GITHUB_ORG=my-org`

| Token type | Required permission |
|---|---|
| **Fine-grained PAT** (recommended) | **Organization permissions → Self-hosted runners: Read and write** |
| **Classic PAT** | scope **`admin:org`** (add `repo` too if the repositories involved are private) |

`admin:org` on a classic PAT is very broad (full organization
administration): for an organization-level runner, always prefer a
**fine-grained PAT** scoped to the "Self-hosted runners" permission, which
is far more limited.

## Practical summary

- **Personal use / a single private repository** → fine-grained PAT,
  repository access set to that repo only, permission **Administration:
  Read and write**.
- **Multiple repositories in the same org need to share the runner** →
  organization-level fine-grained PAT, permission **Self-hosted runners:
  Read and write**.
- **Expiration**: always set an expiration date (max 1 year, ideally 90
  days) on the PAT and note it down for rotation; the container has no way
  to know a PAT has expired ahead of time — the next API call will simply
  fail (and is handled gracefully, see
  [Persistence and self-healing](persistence.md)).

## Where to create it

- Fine-grained PAT: `https://github.com/settings/personal-access-tokens/new`
- Classic PAT: `https://github.com/settings/tokens/new`
