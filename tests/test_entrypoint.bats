#!/usr/bin/env bats
#
# Unit tests for the logic in docker/entrypoint.sh, run with bats
# (https://github.com/bats-core/bats-core). These do not start a real
# runner: they only exercise the pure functions (resolve_scope,
# api_scope_path, config_url, build_labels_arg) and error handling.
#
# Local run: ./tests/run-tests.sh
# CI run:    see .github/workflows/ci.yml

setup() {
    ENTRYPOINT="${BATS_TEST_DIRNAME}/../docker/entrypoint.sh"
    # Reset the variables the script reads, so tests stay isolated.
    unset GITHUB_PAT GITHUB_REPOSITORY GITHUB_ORG GITHUB_SERVER_URL GITHUB_API_URL
    unset RUNNER_NAME RUNNER_LABELS RUNNER_GROUP
    source "${ENTRYPOINT}"
}

@test "resolve_scope: picks 'repo' when GITHUB_REPOSITORY is set" {
    export GITHUB_REPOSITORY="tommasomarchionni/demo"
    run resolve_scope
    [ "$status" -eq 0 ]
    [ "$output" = "repo" ]
}

@test "resolve_scope: picks 'org' when only GITHUB_ORG is set" {
    export GITHUB_ORG="my-org"
    run resolve_scope
    [ "$status" -eq 0 ]
    [ "$output" = "org" ]
}

@test "resolve_scope: prefers 'repo' when both are set" {
    export GITHUB_REPOSITORY="tommasomarchionni/demo"
    export GITHUB_ORG="my-org"
    run resolve_scope
    [ "$status" -eq 0 ]
    [ "$output" = "repo" ]
}

@test "resolve_scope: fails when neither is set" {
    run resolve_scope
    [ "$status" -ne 0 ]
    [[ "$output" == *"GITHUB_REPOSITORY"* ]]
}

@test "api_scope_path: builds the REST path for a repository" {
    export GITHUB_REPOSITORY="tommasomarchionni/demo"
    run api_scope_path "repo"
    [ "$status" -eq 0 ]
    [ "$output" = "repos/tommasomarchionni/demo" ]
}

@test "api_scope_path: builds the REST path for an organization" {
    export GITHUB_ORG="my-org"
    run api_scope_path "org"
    [ "$status" -eq 0 ]
    [ "$output" = "orgs/my-org" ]
}

@test "config_url: builds the config.sh URL for a repository" {
    export GITHUB_REPOSITORY="tommasomarchionni/demo"
    export GITHUB_SERVER_URL="https://github.com"
    run config_url "repo"
    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/tommasomarchionni/demo" ]
}

@test "config_url: respects a custom GITHUB_SERVER_URL (GHES)" {
    export GITHUB_ORG="my-org"
    export GITHUB_SERVER_URL="https://ghes.company.local"
    run config_url "org"
    [ "$status" -eq 0 ]
    [ "$output" = "https://ghes.company.local/my-org" ]
}

@test "build_labels_arg: trims whitespace around commas" {
    run build_labels_arg " ci, docker , dokploy "
    [ "$status" -eq 0 ]
    [ "$output" = "ci,docker,dokploy" ]
}

@test "build_labels_arg: an empty string stays empty" {
    run build_labels_arg ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "require_pat: fails without GITHUB_PAT" {
    run require_pat
    [ "$status" -ne 0 ]
}

@test "require_pat: passes with GITHUB_PAT set" {
    export GITHUB_PAT="ghp_fake_token_for_tests"
    run require_pat
    [ "$status" -eq 0 ]
}

@test "is_configured: false on an empty RUNNER_HOME" {
    export RUNNER_HOME="$(mktemp -d)"
    run is_configured
    [ "$status" -ne 0 ]
    rm -rf "${RUNNER_HOME}"
}

@test "is_configured: true when .runner and .credentials exist" {
    export RUNNER_HOME="$(mktemp -d)"
    touch "${RUNNER_HOME}/.runner" "${RUNNER_HOME}/.credentials"
    run is_configured
    [ "$status" -eq 0 ]
    rm -rf "${RUNNER_HOME}"
}

@test "default values for self-healing on container restart/recreate" {
    [ "${RUNNER_STARTUP_GRACE_SECONDS}" = "20" ]
    [ "${RUNNER_START_MAX_ATTEMPTS}" = "3" ]
    [ "${RUNNER_FORCE_RECONFIGURE}" = "false" ]
}

@test "RUNNER_FORCE_RECONFIGURE can be overridden from the environment" {
    unset RUNNER_FORCE_RECONFIGURE
    export RUNNER_FORCE_RECONFIGURE=true
    source "${ENTRYPOINT}"
    [ "${RUNNER_FORCE_RECONFIGURE}" = "true" ]
}
