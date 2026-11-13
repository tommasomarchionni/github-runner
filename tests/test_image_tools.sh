#!/usr/bin/env bash
# Checks the tools bundled in a built runner image.
#
# Usage:
#   tests/test_image_tools.sh <image> [full|slim]
#
#   full (default)  image built with every INSTALL_* build argument enabled
#   slim            image built with INSTALL_BUILD_TOOLS=false: the base tools
#                   must still be there, the toolchain and Python must not
#
# Every check runs inside the image as the unprivileged runner user, the way
# a workflow job would find it.
#
# The commands passed to in_image are single-quoted on purpose: they must be
# expanded by the shell inside the image, not by this one.
# shellcheck disable=SC2016
set -Eeuo pipefail

image="${1:?usage: tests/test_image_tools.sh <image> [full|slim]}"
variant="${2:-full}"
failures=0

in_image() {
    docker run --rm --entrypoint bash "${image}" -c "$1"
}

pass() { echo "ok   - $1"; }
fail() {
    echo "FAIL - $1" >&2
    failures=$((failures + 1))
}

expect_present() {
    if in_image "command -v $1" > /dev/null 2>&1; then pass "$1 is present"; else fail "$1 is missing"; fi
}

expect_absent() {
    if in_image "command -v $1" > /dev/null 2>&1; then fail "$1 should not be in a slim image"; else pass "$1 is absent"; fi
}

expect_ok() {
    # $1 description, $2 command
    if in_image "$2" > /dev/null 2>&1; then pass "$1"; else fail "$1"; fi
}

# Always bundled, whatever the build arguments.
for tool in git git-lfs curl wget jq tar zip unzip xz zstd bzip2 file rsync ssh ip sudo; do
    expect_present "${tool}"
done
expect_ok "runs as the unprivileged runner user" '[ "$(id -un)" = runner ]'
expect_ok "the local bin directory of the runner user is on PATH" 'case ":${PATH}:" in *":/home/runner/.local/bin:"*) ;; *) exit 1 ;; esac'
expect_ok "zip and unzip round-trip a file" \
    'cd "$(mktemp -d)" && echo hello > a.txt && zip -q a.zip a.txt && rm a.txt && unzip -q a.zip && grep -q hello a.txt'
expect_ok "tar reads zstd and xz archives" \
    'cd "$(mktemp -d)" && echo hello > a.txt && tar --zstd -cf a.tar.zst a.txt && tar -cJf a.tar.xz a.txt && tar --zstd -tf a.tar.zst | grep -q a.txt && tar -tJf a.tar.xz | grep -q a.txt'

case "${variant}" in
    full)
        for tool in docker gh gcc g++ make python3 pip3 pipx; do
            expect_present "${tool}"
        done
        expect_ok "python3 creates a virtual environment" \
            'python3 -m venv /tmp/venv && /tmp/venv/bin/python -c "import sys; assert sys.prefix != sys.base_prefix"'
        expect_ok "gcc compiles and runs a C program" \
            'cd "$(mktemp -d)" && printf "int main(void){return 0;}\n" > t.c && gcc -o t t.c && ./t'
        expect_ok "gh answers without a token" 'gh --version'
        ;;
    slim)
        for tool in gcc g++ make python3 pipx; do
            expect_absent "${tool}"
        done
        ;;
    *)
        echo "unknown variant '${variant}' (full|slim)" >&2
        exit 2
        ;;
esac

if [ "${failures}" -gt 0 ]; then
    echo "${failures} check(s) failed for ${image} (${variant})" >&2
    exit 1
fi
echo "All tool checks passed for ${image} (${variant})."
