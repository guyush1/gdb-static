#!/bin/bash

function apply_patch() {
    # Apply a patch to a directory.
    #
    # Parameters:
    # $1: directory
    # $2: path of patch
    #
    # Returns:
    # 0: success
    # 1: failure

    local dir="$1"
    local patch="$(realpath "$2")"

    pushd "$dir" > /dev/null
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Check if the patch was already applied
    if ! patch -p1 --dry-run < "$patch" &>/dev/null; then
        >&2 echo "Error: patch already applied"
        popd > /dev/null
        return 1
    fi

    patch -p1 < "$patch"
    if [[ $? -ne 0 ]]; then
        popd > /dev/null
        return 1
    fi

    popd > /dev/null
}

function main() {
    if [[ $# -ne 2 ]]; then
        >&2 echo "Usage: $0 <gdb_dir> <gdb_patch>"
        exit 1
    fi

    apply_patch "$1" "$2"
    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to apply GDB patch"
        exit 1
    fi
}

main "$@"
