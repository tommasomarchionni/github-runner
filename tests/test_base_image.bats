#!/usr/bin/env bats
# The base image must stay on an Ubuntu LTS (see docs/bundled-tools.md).
# These tests read the repository files: no Docker needed.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    DOCKERFILE="${REPO_ROOT}/docker/Dockerfile"
    DEPENDABOT="${REPO_ROOT}/.github/dependabot.yml"
}

# The lines of the ignore rule for the ubuntu image, up to the next list item.
ubuntu_ignore_rule() {
    awk '
        /dependency-name: "ubuntu"/ { inside = 1; print; next }
        inside && /^[[:space:]]*- (dependency-name|package-ecosystem):/ { exit }
        inside { print }
    ' "${DEPENDABOT}"
}

@test "the Dockerfile builds on an Ubuntu LTS (YY.04, even year)" {
    run grep -E '^FROM ubuntu:' "${DOCKERFILE}"
    [ "${status}" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    tag="${output#FROM ubuntu:}"
    [[ "${tag}" =~ ^([0-9]{2})\.04$ ]]
    (( 10#${BASH_REMATCH[1]} % 2 == 0 ))
}

@test "Dependabot ignores major bumps of the base image (24.04 -> 25.10)" {
    run ubuntu_ignore_rule
    [ "${status}" -eq 0 ]
    [[ "${output}" == *'version-update:semver-major'* ]]
}

@test "Dependabot ignores minor bumps of the base image (24.04 -> 24.10)" {
    run ubuntu_ignore_rule
    [ "${status}" -eq 0 ]
    [[ "${output}" == *'version-update:semver-minor'* ]]
}

@test "Dependabot still proposes digest updates of the base image" {
    run ubuntu_ignore_rule
    [ "${status}" -eq 0 ]
    [[ "${output}" != *'version-update:semver-patch'* ]]
    [[ "${output}" != *'update-types: []'* ]]
}
