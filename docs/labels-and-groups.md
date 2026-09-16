# Labels and runner groups

- **Labels** (`RUNNER_LABELS`) describe *what kind* of machine this is and
  are used in workflows with `runs-on: [self-hosted, <label>, ...]`. GitHub
  only assigns a job to a runner that has **all** the requested labels.
- The **runner group** (`RUNNER_GROUP`) controls *which repositories* are
  allowed to use the runner, and is only relevant for organization or
  enterprise runners; for a runner scoped to a single repository you can
  leave the default `Default`.

## Example

```env
RUNNER_LABELS=ci,docker,dokploy
```

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, ci, docker]
```

GitHub automatically adds `self-hosted` and the OS/architecture labels; you
only need to list your custom ones plus `self-hosted` in the workflow.

## Organization runner groups

Runner groups are only available for organization- or enterprise-level
runners (`GITHUB_ORG`). You can combine a group and labels in a workflow:

```yaml
runs-on:
  group: ci
  labels: [self-hosted, linux, x64]
```

The runner must belong to that group **and** have the listed labels.
