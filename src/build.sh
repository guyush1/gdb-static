#!/bin/bash

function set_compliation_variables() {
    # Set compilation variables such as which compiler to use.
    #
    # Parameters:
    # $1: target architecture
    #
    # Returns:
    # 0: success
    # 1: failure
    supported_archs=("arm" "aarch64" "powerpc" "x86_64")

    local target_arch="$1"

    if [[ ! " ${supported_archs[@]} " =~ " ${target_arch} " ]]; then
        >&2 echo "Error: unsupported target architecture: $target_arch"
        return 1
    fi

    if [[ "$target_arch" == "arm" ]]; then
        CROSS=arm-linux-gnueabi-
        export HOST=arm-linux-gnueabi
    elif [[ "$target_arch" == "aarch64" ]]; then
        CROSS=aarch64-linux-gnu-
        export HOST=aarch64-linux-gnu
    elif [[ "$target_arch" == "powerpc" ]]; then
        CROSS=powerpc-linux-gnu-
        export HOST=powerpc-linux-gnu
    elif [[ "$target_arch" == "x86_64" ]]; then
        CROSS=""
        export HOST=x86_64-linux-gnu
    fi

    export CC="${CROSS}gcc"
    export CXX="${CROSS}g++"

    export CFLAGS="-O2"
    export CXXFLAGS="-O2"
}

function build_iconv() {
    # Build libiconv.
    #
    # Parameters:
    # $1: iconv package directory
    # $2: target architecture
    #
    # Echoes:
    # The libiconv build directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local iconv_dir="$1"
    local target_arch="$2"
    local iconv_build_dir="$(realpath "$iconv_dir/build-$target_arch")"

    echo "$iconv_build_dir"
    mkdir -p "$iconv_build_dir"

    if [[ -f "$iconv_build_dir/lib/.libs/libiconv.a" ]]; then
        >&2 echo "Skipping build: iconv already built for $target_arch"
        return 0
    fi

    pushd "$iconv_build_dir" > /dev/null

    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    cp -r ./include ./lib/.libs/
    mkdir -p ./lib/.libs/lib/
    cp ./lib/.libs/libiconv.a ./lib/.libs/lib/

    popd > /dev/null
}

function build_libgmp() {
    # Build libgmp.
    #
    # Parameters:
    # $1: libgmp package directory
    # $2: target architecture
    #
    # Echoes:
    # The libgmp build directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local gmp_dir="$1"
    local target_arch="$2"
    local gmp_build_dir="$(realpath "$gmp_dir/build-$target_arch")"

    echo "$gmp_build_dir"
    mkdir -p "$gmp_build_dir"

    if [[ -f "$gmp_build_dir/.libs/lib/libgmp.a" ]]; then
        >&2 echo "Skipping build: libgmp already built for $target_arch"
        return 0
    fi

    pushd "$gmp_build_dir" > /dev/null

    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    mkdir -p ./.libs/include/
    cp gmp.h ./.libs/include/
    mkdir -p ./.libs/lib/
    cp ./.libs/libgmp.a ./.libs/lib/

    popd > /dev/null
}

function build_libmpfr() {
    # Build libmpfr.
    #
    # Parameters:
    # $1: mpfr package directory
    # $2: libgmp build directory
    # $3: target architecture
    #
    # Echoes:
    # The libmpfr build directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local mpfr_dir="$1"
    local libgmp_build_dir="$2"
    local target_arch="$3"
    local mpfr_build_dir="$(realpath "$mpfr_dir/build-$target_arch")"

    mkdir -p "$mpfr_build_dir"
    echo "$mpfr_build_dir"

    if [[ -f "$mpfr_build_dir/src/.libs/lib/libmpfr.a" ]]; then
        >&2 echo "Skipping build: libmpfr already built for $target_arch"
        return 0
    fi

    pushd "$mpfr_dir/build-$target_arch" > /dev/null

    ../configure --enable-static "--with-gmp-build=$libgmp_build_dir" \
        "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    mkdir -p ./src/.libs/include
    cp ../src/mpfr.h ./src/.libs/include/
    mkdir -p ./src/.libs/lib
    cp ./src/.libs/libmpfr.a ./src/.libs/lib/

    popd > /dev/null
}

function build_gdb() {
    # Configure and build gdb.
    #
    # Parameters:
    # $1: gdb directory
    # $2: target architecture
    # $3: libiconv prefix
    # $4: libgmp prefix
    # $5: libmpfr prefix
    #
    # Echoes:
    # The gdb build directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_dir="$1"
    local target_arch="$2"
    local libiconv_prefix="$3"
    local libgmp_prefix="$4"
    local libmpfr_prefix="$5"
    local gdb_build_dir="$(realpath "$gdb_dir/build-$target_arch")"

    echo "$gdb_build_dir"
    mkdir -p "$gdb_build_dir"

    if [[ -f "$gdb_build_dir/gdb/gdb" ]]; then
        >&2 echo "Skipping build: gdb already built for $target_arch"
        return 0
    fi

    pushd "$gdb_build_dir" > /dev/null

    ../configure --enable-static --with-static-standard-libraries --disable-tui --disable-inprocess-agent \
                 "--with-libiconv-prefix=$libiconv_prefix" --with-libiconv-type=static \
                 "--with-gmp=$libgmp_prefix" \
                 "--with-mpfr=$libmpfr_prefix" \
                 "CC=$CC" "CXX=$CXX" "--host=$HOST" \
                 "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    popd > /dev/null
}

function install_gdb() {
    # Install gdb binaries to an artifacts directory.
    #
    # Parameters:
    # $1: gdb build directory
    # $2: artifacts directory
    # $3: target architecture
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_build_dir="$1"
    local artifacts_dir="$2"
    local target_arch="$3"

    if [[ -d "$artifacts_dir/$target_arch" && -n "$(ls -A "$artifacts_dir/$target_arch")" ]]; then
        >&2 echo "Skipping install: gdb already installed for $target_arch"
        return 0
    fi

    temp_artifacts_dir="$(mktemp -d)"

    mkdir -p "$artifacts_dir/$target_arch"

    make -C "$gdb_build_dir" install "DESTDIR=$temp_artifacts_dir" 1>&2
    if [[ $? -ne 0 ]]; then
        rm -rf "$temp_artifacts_dir"
        return 1
    fi

    while read file; do
        cp "$file" "$artifacts_dir/$target_arch/"
    done < <(find "$temp_artifacts_dir/usr/local/bin" -type f -executable)

    rm -rf "$temp_artifacts_dir"
}

function build_and_install_gdb() {
    # Build gdb and install it to an artifacts directory.
    #
    # Parameters:
    # $1: gdb package directory
    # $2: libiconv prefix
    # $3: libgmp prefix
    # $4: libmpfr prefix
    # $5: install directory
    # $6: target architecture
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_dir="$1"
    local libiconv_prefix="$2"
    local libgmp_prefix="$3"
    local libmpfr_prefix="$4"
    local artifacts_dir="$5"
    local target_arch="$6"

    gdb_build_dir="$(build_gdb "$gdb_dir" "$target_arch" "$libiconv_prefix" "$libgmp_prefix" "$libmpfr_prefix")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    install_gdb "$gdb_build_dir" "$artifacts_dir" "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
}

function build_gdb_with_dependencies() {
    # Build gdb for a specific target architecture.
    #
    # Parameters:
    # $1: target architecture
    # $2: build directory

    local target_arch="$1"
    local build_dir="$2"
    local packages_dir="$build_dir/packages"
    local artifacts_dir="$build_dir/artifacts"

    set_compliation_variables "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    mkdir -p "$packages_dir"

    iconv_build_dir="$(build_iconv "$packages_dir/libiconv" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    gmp_build_dir="$(build_libgmp "$packages_dir/gmp" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    mpfr_build_dir="$(build_libmpfr "$packages_dir/mpfr" "$gmp_build_dir" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    build_and_install_gdb "$packages_dir/gdb" \
                      "$iconv_build_dir/lib/.libs/" \
                      "$gmp_build_dir/.libs/" \
                      "$mpfr_build_dir/src/.libs/" \
                      "$artifacts_dir" \
                      "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
}

function main() {
    if [[ $# -ne 3 ]]; then
        >&2 echo "Usage: $0 <target_arch> <build_dir>"
        exit 1
    fi

    build_gdb_with_dependencies "$1" "$2"
    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to build gdb with dependencies"
        exit 1
    fi
}

main "$@"
