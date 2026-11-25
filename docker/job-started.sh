#!/bin/sh
# Job-started hook of the runner image (ACTIONS_RUNNER_HOOK_JOB_STARTED).
#
# The job working copy (`_work/<repo>/<repo>`) lives in the runner's volume and survives jobs and
# container restarts. When a tracking ref (`refs/remotes/...`) is unreadable or points to an object
# the clone does not have (a force-pushed branch, a fetch or gc cut short by a container stop), the
# next job's checkout dies with `bad object` or `reference broken`, and restarting the runner does
# not remove the ref. This hook removes ONLY those refs, before every job; the checkout's fetch
# recreates them. Local branches, tags and the working tree are never touched.
#
# It never fails the job: every error is ignored and it always exits 0. It reads no secret.
set +e

workdir="${RUNNER_WORKDIR:-_work}"
case "${workdir}" in
    /*) root="${workdir}" ;;
    *) root="${RUNNER_HOME:-/home/runner/actions-runner}/${workdir}" ;;
esac

is_oid() {
    case "$1" in
        *[!0-9a-f]* | '') return 1 ;;
    esac
    [ "${#1}" -eq 40 ] || [ "${#1}" -eq 64 ]
}

for gitdir in "${root}"/*/*/.git; do
    [ -d "${gitdir}" ] || continue

    # Loose refs: an empty file, something that is not an object id, or an id the clone lacks.
    if [ -d "${gitdir}/refs/remotes" ]; then
        find "${gitdir}/refs/remotes" -type f 2>/dev/null | while IFS= read -r ref; do
            oid="$(head -n 1 "${ref}" 2>/dev/null | tr -d ' \t\r')"
            if ! is_oid "${oid}" || ! git --git-dir="${gitdir}" cat-file -e "${oid}^{commit}" 2>/dev/null; then
                rm -f "${ref}" && echo "job-started: removed the broken ref ${ref#"${gitdir}"/}"
            fi
        done
    fi

    # Packed refs whose object is missing: the file is rewritten without those lines.
    if [ -f "${gitdir}/packed-refs" ]; then
        kept="${gitdir}/packed-refs.job-started.$$"
        : >"${kept}" || continue
        changed=0
        while IFS= read -r line; do
            case "${line}" in
                [0-9a-f]*" refs/remotes/"*)
                    oid="${line%% *}"
                    if ! git --git-dir="${gitdir}" cat-file -e "${oid}^{commit}" 2>/dev/null; then
                        echo "job-started: removed the broken ref ${line#* }"
                        changed=1
                        continue
                    fi
                    ;;
            esac
            printf '%s\n' "${line}" >>"${kept}"
        done <"${gitdir}/packed-refs"
        if [ "${changed}" -eq 1 ]; then mv -f "${kept}" "${gitdir}/packed-refs"; else rm -f "${kept}"; fi
    fi
done

exit 0
