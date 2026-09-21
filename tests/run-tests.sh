#!/usr/bin/env bash
# Runs the full verification suite locally, using Docker so nothing needs
# to be installed on the host (bats/shellcheck/hadolint/mkdocs).
#
# Usage:
#   ./tests/run-tests.sh
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Shellcheck on docker/entrypoint.sh"
docker run --rm -v "$(pwd)":/mnt -w /mnt koalaman/shellcheck:stable docker/entrypoint.sh

echo "==> Hadolint on docker/Dockerfile"
docker run --rm -i hadolint/hadolint < docker/Dockerfile

echo "==> Unit tests (bats) on docker/entrypoint.sh"
docker run --rm -v "$(pwd)":/code -w /code bats/bats:latest tests/test_entrypoint.bats

echo "==> Docker image build"
docker build -t github-runner:test -f docker/Dockerfile docker

echo "==> Verify bundled tools in the image"
docker run --rm --entrypoint docker github-runner:test --version
docker run --rm --entrypoint ip github-runner:test -V

echo "==> Docs site build (mkdocs --strict)"
docker run --rm -v "$(pwd)":/docs -w /docs python:3.12-slim bash -c \
  "pip install --quiet -r docs/requirements.txt && mkdocs build --strict"

echo
echo "All checks passed."
