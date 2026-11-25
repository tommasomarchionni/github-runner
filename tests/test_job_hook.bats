#!/usr/bin/env bats
# The job-started hook of the image (docker/job-started.sh, docs/persistence.md): it removes the
# tracking refs of the job working copy that are unreadable or point to a missing object, and
# nothing else. These tests run the script against throwaway git repositories and read the
# Dockerfile: no image build needed.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    HOOK="${REPO_ROOT}/docker/job-started.sh"
    DOCKERFILE="${REPO_ROOT}/docker/Dockerfile"
    RUNNER_HOME="$(mktemp -d)"
    export RUNNER_HOME
    unset RUNNER_WORKDIR
    REPO="${RUNNER_HOME}/_work/repo/repo"
    mkdir -p "${REPO}"
    git -C "${REPO}" init -q -b main
    echo 'work in progress' >"${REPO}/file.txt"
    git -C "${REPO}" add file.txt
    git -C "${REPO}" -c user.name=t -c user.email=t@example.com commit -q -m first
    COMMIT="$(git -C "${REPO}" rev-parse HEAD)"
    MISSING=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
    mkdir -p "${REPO}/.git/refs/remotes/origin"
}

teardown() {
    rm -rf "${RUNNER_HOME}"
}

@test "a loose ref that points to a missing object is removed and a good ref is kept" {
    echo "${MISSING}" >"${REPO}/.git/refs/remotes/origin/release-please--branches--main"
    echo "${COMMIT}" >"${REPO}/.git/refs/remotes/origin/main"
    run sh "${HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"release-please--branches--main"* ]]
    [ ! -e "${REPO}/.git/refs/remotes/origin/release-please--branches--main" ]
    [ "$(cat "${REPO}/.git/refs/remotes/origin/main")" = "${COMMIT}" ]
}

@test "an empty or garbled ref is removed" {
    : >"${REPO}/.git/refs/remotes/origin/empty"
    echo 'not-an-object-id' >"${REPO}/.git/refs/remotes/origin/garbled"
    run sh "${HOOK}"
    [ "${status}" -eq 0 ]
    [ ! -e "${REPO}/.git/refs/remotes/origin/empty" ]
    [ ! -e "${REPO}/.git/refs/remotes/origin/garbled" ]
}

@test "a packed ref with a missing object is removed and the others stay" {
    printf '# pack-refs with: peeled fully-peeled sorted \n%s refs/remotes/origin/main\n%s refs/remotes/origin/gone\n' \
        "${COMMIT}" "${MISSING}" >"${REPO}/.git/packed-refs"
    run sh "${HOOK}"
    [ "${status}" -eq 0 ]
    ! grep -q 'refs/remotes/origin/gone' "${REPO}/.git/packed-refs"
    grep -q 'refs/remotes/origin/main' "${REPO}/.git/packed-refs"
    [ "$(git -C "${REPO}" rev-parse origin/main)" = "${COMMIT}" ]
}

@test "local branches, tags and the working tree are left alone" {
    git -C "${REPO}" tag v1
    git -C "${REPO}" branch feature
    echo 'edited and not committed' >"${REPO}/file.txt"
    run sh "${HOOK}"
    [ "${status}" -eq 0 ]
    [ "$(git -C "${REPO}" rev-parse feature)" = "${COMMIT}" ]
    [ "$(git -C "${REPO}" rev-parse v1)" = "${COMMIT}" ]
    [ "$(cat "${REPO}/file.txt")" = 'edited and not committed' ]
}

@test "RUNNER_WORKDIR can be an absolute path" {
    other="$(mktemp -d)"
    mkdir -p "${other}/repo/repo"
    git -C "${other}/repo/repo" init -q -b main
    mkdir -p "${other}/repo/repo/.git/refs/remotes/origin"
    echo "${MISSING}" >"${other}/repo/repo/.git/refs/remotes/origin/gone"
    RUNNER_WORKDIR="${other}" run sh "${HOOK}"
    [ "${status}" -eq 0 ]
    [ ! -e "${other}/repo/repo/.git/refs/remotes/origin/gone" ]
    rm -rf "${other}"
}

@test "with no working copy yet it prints nothing and exits 0" {
    rm -rf "${RUNNER_HOME}/_work"
    run sh "${HOOK}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "the image copies the hook, makes it executable and points the runner at it" {
    grep -qF 'COPY --chown=runner:runner job-started.sh /home/runner/job-started.sh' "${DOCKERFILE}"
    grep -qF 'RUN chmod +x /home/runner/job-started.sh' "${DOCKERFILE}"
    grep -qx 'ENV ACTIONS_RUNNER_HOOK_JOB_STARTED=/home/runner/job-started.sh' "${DOCKERFILE}"
}
