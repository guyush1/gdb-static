#!/bin/bash

# Include utils library
script_dir=$(dirname "$0")
source "$script_dir/utils.sh"

# List of package URLs to download
SOURCE_URLS=(
    "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz"
    "https://ftp.gnu.org/pub/gnu/gmp/gmp-6.3.0.tar.xz"
    "https://ftp.gnu.org/pub/gnu/mpfr/mpfr-4.2.1.tar.xz"
    "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.5.tar.gz"
)

function unpack_tarball() {
    # Unpack a tarball based on its extension.
    # Supported extensions: tar, gz, xz.
    #
    # Parameters:
    # $1: tarball
    #
    # Returns:
    # 0: success
    # 1: failure

    local tarball="$1"
    local extension="${tarball##*.}"

    if [[ ! -f "$tarball" ]]; then
        >&2 echo "Error: $tarball does not exist"
        return 1
    fi

    case "$extension" in
        tar | xz)
            tar xf "$tarball"
            ;;
        gz)
            tar xzf "$tarball"
            ;;
        *)
            >&2 echo "Error: unknown extension $extension"
            return 1
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to unpack $tarball"
        return 1
    fi
}

function download_package() {
    # Download a package. Will skip download if the output file already exists.
    #
    # Parameters:
    # $1: URL of the package
    # $2: output file
    #
    # Returns:
    # 0: success
    # 1: failure

    local url="$1"
    local output="$2"

    wget "$url" -O "$output"
    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to download $url"
        return 1
    fi
}

function extract_package() {
    # Extract a package. Will skip extraction if the package directory already exists.
    #
    # Parameters:
    # $1: package tarball
    # $2: output directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local tarball="$1"
    local output_dir="$2"
    local package_dir="${tarball%.tar*}"
    local tarball_realpath="$(realpath "$tarball")"
    local temp_dir="$(mktemp -d)"

    if [[ ! -f "$tarball" ]]; then
        >&2 echo "Error: $tarball does not exist"
        return 1
    fi

    pushd "$temp_dir" > /dev/null

    unpack_tarball "$tarball_realpath"
    if [[ $? -ne 0 ]]; then
        popd > /dev/null
        return 1
    fi

    popd > /dev/null

    # Make sure output dir is empty, so we could move content into it.
    # The directory might not exist, so we need to pass || true so that set -e won't fail us.
    rm -rf "$output_dir" || true

    mv "$temp_dir/$package_dir" "$output_dir"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    rm -rf "$temp_dir"
}

function download_and_extract_package() {
    # Download and extract a package.
    #
    # Parameters:
    # $1: URL of the package
    # $2: output directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local url="$1"
    local output_dir="$2"
    local tarball=$(basename "$url")

    download_package "$url" "$tarball"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    extract_package "$tarball" "$output_dir"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
}

function package_url_to_dir() {
    # Convert a package URL to a directory name.
    #
    # Parameters:
    # $1: package URL
    #
    # Echoes:
    # The package directory name
    #
    # Returns:
    # 0: success
    # 1: failure

    local url="$1"

    # The name of the package is the basename of the URL without the version number.
    local package_dir=$(basename "$url")
    package_dir="${package_dir%%-*}"

    echo "$package_dir"
}

function download_gdb_packages() {
    # Download and extract all required packages for building GDB.
    #
    # Parameters:
    # $1: packages directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local packages_dir="$1"
    pushd "$packages_dir"

    # Run downloads in parallel
    download_pids=()

    fancy_title "Starting download of GDB packages"

    for url in "${SOURCE_URLS[@]}"; do
        package_dir=$(package_url_to_dir "$url")
        download_and_extract_package "$url" "$package_dir" &
        download_pids+=($!)
    done

    for pid in "${download_pids[@]}"; do
        wait "$pid"
        if [[ $? -ne 0 ]]; then
            popd
            return 1
        fi
    done

    fancy_title "Finished downloading GDB packages"
    popd
}

function main() {
    if [[ $# -ne 1 ]]; then
        >&2 echo "Usage: $0 <packages_dir>"
        exit 1
    fi

    download_gdb_packages "$1"
    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to download GDB packages"
        exit 1
    fi
}

main "$@"
