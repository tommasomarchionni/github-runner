#!/usr/bin/env bash
#
# Entrypoint for the containerized GitHub Actions self-hosted runner.
#
# Uses a Personal Access Token (PAT) to mint a short-lived registration
# token on every start, so the container can be stopped/recreated/redeployed
# indefinitely without ever touching the GitHub UI again.
#
# Supported scopes (pick ONE):
#   - Repository runner : set GITHUB_REPOSITORY="owner/repo"
#   - Organization runner: set GITHUB_ORG="my-org" (GITHUB_REPOSITORY unset)
#
# See README.md for the full environment variable reference.

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Defaults (all overridable via environment variables)
# ---------------------------------------------------------------------------
: "${GITHUB_SERVER_URL:=https://github.com}"
: "${GITHUB_API_URL:=https://api.github.com}"
: "${RUNNER_NAME:=$(hostname)}"
: "${RUNNER_LABELS:=}"
: "${RUNNER_GROUP:=Default}"
: "${RUNNER_WORKDIR:=_work}"
: "${RUNNER_EPHEMERAL:=false}"
: "${RUNNER_DISABLE_UPDATE:=true}"
: "${RUNNER_REPLACE:=true}"
: "${RUNNER_UNREGISTER_TIMEOUT:=30}"
: "${LOG_LEVEL:=info}"
: "${EXTRA_CONFIG_ARGS:=}"
# Self-healing on container destroy/recreate: if a *stale* registration is
# left in the persistent volume (e.g. the runner was removed from the
# GitHub UI, the credentials were invalidated, or the volume was copied
# from another host), run.sh fails almost immediately. When that happens
# within RUNNER_STARTUP_GRACE_SECONDS of starting, we wipe the local state
# and re-register from scratch using the PAT, up to RUNNER_START_MAX_ATTEMPTS
# times, instead of crash-looping forever with an unusable registration.
: "${RUNNER_STARTUP_GRACE_SECONDS:=20}"
: "${RUNNER_START_MAX_ATTEMPTS:=3}"
# Set to "true" to force-wipe the local registration on the NEXT start even
# if it looks valid (manual escape hatch for troubleshooting). Remember to
# set it back to "false" afterwards, otherwise every restart re-registers.
: "${RUNNER_FORCE_RECONFIGURE:=false}"

RUNNER_HOME="${RUNNER_HOME:-/home/runner/actions-runner}"
RUNNER_PID=""

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()   { printf '[entrypoint] %s\n' "$*" >&2; }
debug() { [[ "${LOG_LEVEL}" == "debug" ]] && printf '[entrypoint][debug] %s\n' "$*" >&2 || true; }
die()   { printf '[entrypoint][error] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
require_pat() {
    [[ -n "${GITHUB_PAT:-}" ]] || die "GITHUB_PAT is required (a fine-grained or classic Personal Access Token)."
}

# Resolves whether we are registering against a repository or an organization
# and prints "repo" or "org". Dies if the configuration is ambiguous/missing.
resolve_scope() {
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        echo "repo"
    elif [[ -n "${GITHUB_ORG:-}" ]]; then
        echo "org"
    else
        die "Set either GITHUB_REPOSITORY=\"owner/repo\" or GITHUB_ORG=\"my-org\"."
    fi
}

# Prints the base REST API path segment for the resolved scope, e.g.
#   repo -> repos/owner/repo
#   org  -> orgs/my-org
api_scope_path() {
    local scope="$1"
    case "$scope" in
        repo) echo "repos/${GITHUB_REPOSITORY}" ;;
        org)  echo "orgs/${GITHUB_ORG}" ;;
        *)    die "Unknown scope: ${scope}" ;;
    esac
}

# Prints the config.sh --url target for the resolved scope.
config_url() {
    local scope="$1"
    case "$scope" in
        repo) echo "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" ;;
        org)  echo "${GITHUB_SERVER_URL}/${GITHUB_ORG}" ;;
        *)    die "Unknown scope: ${scope}" ;;
    esac
}

# Builds the comma-separated --labels value, or empty string if none given.
build_labels_arg() {
    local labels="${1:-}"
    # Trim accidental whitespace around commas.
    labels="$(echo "${labels}" | tr -d ' ')"
    echo "${labels}"
}

# ---------------------------------------------------------------------------
# GitHub API calls (PAT-authenticated)
# ---------------------------------------------------------------------------
# $1 = HTTP method, $2 = path (relative to GITHUB_API_URL), $3 = optional scope label for errors
gh_api() {
    local method="$1" path="$2"
    local response http_code body

    response="$(curl -sS -w '\n%{http_code}' \
        -X "${method}" \
        -H "Authorization: Bearer ${GITHUB_PAT}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${GITHUB_API_URL}/${path}")"

    http_code="$(tail -n1 <<<"${response}")"
    body="$(sed '$d' <<<"${response}")"

    if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
        log "GitHub API call failed (HTTP ${http_code}) for ${GITHUB_API_URL}/${path}"
        log "Response: ${body}"
        die "Check that GITHUB_PAT has the right scope/permissions (see README) and that GITHUB_REPOSITORY/GITHUB_ORG is correct."
    fi

    echo "${body}"
}

get_registration_token() {
    local scope="$1" scope_path
    scope_path="$(api_scope_path "${scope}")"
    gh_api POST "${scope_path}/actions/runners/registration-token" | jq -r '.token'
}

get_removal_token() {
    local scope="$1" scope_path
    scope_path="$(api_scope_path "${scope}")"
    gh_api POST "${scope_path}/actions/runners/remove-token" | jq -r '.token'
}

# ---------------------------------------------------------------------------
# Runner lifecycle
# ---------------------------------------------------------------------------
is_configured() {
    [[ -f "${RUNNER_HOME}/.runner" && -f "${RUNNER_HOME}/.credentials" ]]
}

configure_runner() {
    local scope="$1" reg_token url labels_arg
    reg_token="$(get_registration_token "${scope}")"
    [[ -n "${reg_token}" && "${reg_token}" != "null" ]] || die "Could not obtain a registration token from GitHub."
    url="$(config_url "${scope}")"
    labels_arg="$(build_labels_arg "${RUNNER_LABELS}")"

    local -a args=(
        --unattended
        --url "${url}"
        --token "${reg_token}"
        --name "${RUNNER_NAME}"
        --work "${RUNNER_WORKDIR}"
        --runnergroup "${RUNNER_GROUP}"
    )
    [[ -n "${labels_arg}" ]] && args+=(--labels "${labels_arg}")
    [[ "${RUNNER_REPLACE}" == "true" ]] && args+=(--replace)
    [[ "${RUNNER_DISABLE_UPDATE}" == "true" ]] && args+=(--disableupdate)
    [[ "${RUNNER_EPHEMERAL}" == "true" ]] && args+=(--ephemeral)

    # shellcheck disable=SC2206
    [[ -n "${EXTRA_CONFIG_ARGS}" ]] && args+=(${EXTRA_CONFIG_ARGS})

    log "Registering runner '${RUNNER_NAME}' (scope=${scope}, group=${RUNNER_GROUP}, labels=${labels_arg:-<none>}, ephemeral=${RUNNER_EPHEMERAL})"
    debug "config.sh args: ${args[*]//${reg_token}/***}"
    "${RUNNER_HOME}/config.sh" "${args[@]}"
}

deregister_runner() {
    local scope="$1" rem_token
    log "Deregistering runner '${RUNNER_NAME}' from GitHub..."
    if rem_token="$(get_removal_token "${scope}" 2>/dev/null)" && [[ -n "${rem_token}" && "${rem_token}" != "null" ]]; then
        "${RUNNER_HOME}/config.sh" remove --unattended --token "${rem_token}" || log "Deregistration reported an error (safe to ignore if the runner already finished its job in --ephemeral mode)."
    else
        log "Could not obtain a removal token (PAT may have expired); the container will still stop."
    fi
}

# Forwards SIGTERM/SIGINT to the runner and waits for a clean shutdown,
# then deregisters the runner from GitHub before letting the container exit.
cleanup() {
    local scope="$1"
    trap - SIGTERM SIGINT
    log "Caught shutdown signal."
    if [[ -n "${RUNNER_PID}" ]] && kill -0 "${RUNNER_PID}" 2>/dev/null; then
        kill -TERM "${RUNNER_PID}" 2>/dev/null || true
        local waited=0
        while kill -0 "${RUNNER_PID}" 2>/dev/null && (( waited < RUNNER_UNREGISTER_TIMEOUT )); do
            sleep 1
            (( waited += 1 ))
        done
        kill -0 "${RUNNER_PID}" 2>/dev/null && kill -KILL "${RUNNER_PID}" 2>/dev/null || true
    fi
    deregister_runner "${scope}"
    exit 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    require_pat
    local scope
    scope="$(resolve_scope)"

    cd "${RUNNER_HOME}"

    trap 'cleanup "'"${scope}"'"' SIGTERM SIGINT

    local attempt=1
    while (( attempt <= RUNNER_START_MAX_ATTEMPTS )); do
        if [[ "${RUNNER_EPHEMERAL}" == "true" || "${RUNNER_FORCE_RECONFIGURE}" == "true" ]]; then
            # Ephemeral runners are single-use: never resume a stale registration.
            # RUNNER_FORCE_RECONFIGURE is the manual escape hatch for troubleshooting.
            rm -f .runner .credentials .credentials_rsaparams
        fi

        if is_configured; then
            log "Existing runner registration found in the persistent volume (attempt ${attempt}/${RUNNER_START_MAX_ATTEMPTS}); reusing it."
        else
            configure_runner "${scope}"
        fi

        log "Starting runner (attempt ${attempt}/${RUNNER_START_MAX_ATTEMPTS})..."
        SECONDS=0
        "${RUNNER_HOME}/run.sh" &
        RUNNER_PID=$!
        wait "${RUNNER_PID}"
        local exit_code=$? elapsed=${SECONDS}
        RUNNER_PID=""

        if [[ "${exit_code}" -eq 0 ]]; then
            log "Runner exited cleanly (this is expected right after a job in --ephemeral mode, or on a controlled stop)."
            deregister_runner "${scope}"
            exit 0
        fi

        # A registration left over from a destroyed/recreated container (or one
        # removed manually from the GitHub UI) makes run.sh fail almost
        # immediately. Treat a fast non-zero exit as "stale state" and
        # self-heal by wiping it and registering again with a fresh PAT-minted
        # token, instead of crash-looping with credentials that can never work.
        if (( elapsed < RUNNER_STARTUP_GRACE_SECONDS )) && (( attempt < RUNNER_START_MAX_ATTEMPTS )); then
            log "Runner exited after only ${elapsed}s with exit code ${exit_code}: the registration in the volume looks stale/invalid."
            log "Wiping local runner state and re-registering (attempt $(( attempt + 1 ))/${RUNNER_START_MAX_ATTEMPTS})..."
            deregister_runner "${scope}" 2>/dev/null || true
            rm -f .runner .credentials .credentials_rsaparams
            sleep "$(( attempt * 5 ))"
            (( attempt += 1 ))
            continue
        fi

        log "Runner exited with code ${exit_code} after ${elapsed}s; giving up after ${attempt} attempt(s)."
        deregister_runner "${scope}"
        exit "${exit_code}"
    done

    die "Runner failed to start after ${RUNNER_START_MAX_ATTEMPTS} attempt(s)."
}

# Allow this file to be `source`d (e.g. from bats tests) without executing main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
