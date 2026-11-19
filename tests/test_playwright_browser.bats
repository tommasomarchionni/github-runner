#!/usr/bin/env bats
# The Playwright browser of the image (see docs/bundled-tools.md, "Playwright browser").
# These tests read the Dockerfile: no Docker needed. tests/test_image_tools.sh checks the
# built image.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    DOCKERFILE="${REPO_ROOT}/docker/Dockerfile"
}

@test "the Playwright version is one build argument with an exact default, before the first FROM" {
    run grep -nE '^ARG PLAYWRIGHT_VERSION=' "${DOCKERFILE}"
    [ "${status}" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${output}" =~ ^([0-9]+):ARG\ PLAYWRIGHT_VERSION=[0-9]+\.[0-9]+\.[0-9]+$ ]]
    first_from="$(grep -nE '^FROM ' "${DOCKERFILE}" | head -n1 | cut -d: -f1)"
    (( BASH_REMATCH[1] < first_from ))
}

@test "Node.js and the Playwright command line stay in a build stage" {
    run grep -cE '^FROM node:[0-9]+\.[0-9]+\.[0-9]+-[a-z]+-slim AS playwright-cli$' "${DOCKERFILE}"
    [ "${output}" -eq 1 ]
    # The final stage mounts it for one RUN and never copies it.
    run grep -E 'COPY --from=playwright-cli' "${DOCKERFILE}"
    [ "${status}" -ne 0 ]
    run grep -cE 'mount=type=bind,from=playwright-cli' "${DOCKERFILE}"
    [ "${output}" -eq 1 ]
}

@test "browsers live in /opt/ms-playwright, with the version they are for" {
    grep -qx 'ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright' "${DOCKERFILE}"
    grep -qF '"${PLAYWRIGHT_BROWSERS_PATH}/.playwright-version"' "${DOCKERFILE}"
    grep -qF 'chown -R runner:runner "${PLAYWRIGHT_BROWSERS_PATH}"' "${DOCKERFILE}"
}

@test "the system libraries are listed in the Dockerfile and checked by Playwright itself" {
    # No --with-deps and no install-deps that installs: the packages are explicit.
    run bash -c "grep -vE '^[[:space:]]*#' '${DOCKERFILE}' | grep -E 'with-deps|install-deps chromium'"
    [ "${status}" -ne 0 ]
    grep -qF 'install-deps --dry-run chromium' "${DOCKERFILE}"
    grep -qF "All system dependencies are installed." "${DOCKERFILE}"
    for package in libnss3 libgbm1 libasound2t64 xvfb fonts-liberation; do
        grep -qE "^ +${package} \\\\$|^ +${package} ;" "${DOCKERFILE}"
    done
}

@test "the browser can be left out with a build argument" {
    grep -qx 'ARG INSTALL_PLAYWRIGHT_CHROMIUM=true' "${DOCKERFILE}"
}
