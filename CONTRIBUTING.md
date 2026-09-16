# Contributing

Thanks for considering a contribution to this project.

## Ways to contribute

- **Bug reports**: open an issue using the "Bug report" template. Include
  your `docker logs` output (with the PAT redacted — the entrypoint never
  prints it, but double-check), the relevant environment variables (never
  paste `GITHUB_PAT`), and steps to reproduce.
- **Feature requests**: open an issue using the "Feature request" template.
- **Documentation**: the docs live in `docs/` and are built with
  [MkDocs Material](https://squidfunk.github.io/mkdocs-material/). Typo
  fixes and clarifications are always welcome.
- **Code**: see the workflow below.

## Development setup

```bash
git clone https://github.com/tommasomarchionni/github-runner.git
cd github-runner
cp .env.example .env
# edit .env with a PAT scoped to a disposable test repository
```

Build and run locally:

```bash
docker compose up -d --build
docker compose logs -f
```

## Running the test suite locally

The full suite (shellcheck, hadolint, bats, image build) runs in Docker so
you don't need to install anything beyond Docker itself:

```bash
./tests/run-tests.sh
```

See [Testing and CI](docs/testing.md) for details on each check.

## Documentation site

Preview the documentation site locally:

```bash
pip install -r docs/requirements.txt
mkdocs serve
```

Then open `http://127.0.0.1:8000/`.

## Pull request checklist

- [ ] `./tests/run-tests.sh` passes locally.
- [ ] Shell scripts are formatted consistently and pass `shellcheck`.
- [ ] New environment variables are documented in
      `docs/environment-variables.md` and added to `.env.example`.
- [ ] Behavioral changes are reflected in the relevant `docs/*.md` page.
- [ ] `CHANGELOG.md` has a new entry under "Unreleased".

## Commit style

This project loosely follows [Conventional Commits](https://www.conventionalcommits.org/)
(`fix:`, `feat:`, `docs:`, `chore:`, ...) to keep history and the changelog
readable, but this is a guideline, not a hard requirement enforced by CI.

## Code of Conduct

By participating in this project, you agree to abide by the
[Code of Conduct](CODE_OF_CONDUCT.md).
