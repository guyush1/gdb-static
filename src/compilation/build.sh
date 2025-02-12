#!/bin/bash

# Include utils library
script_dir=$(dirname "$0")
source "$script_dir/utils.sh"

# Don't want random unknown things to fail in the build procecss!
set -e

function set_compliation_variables() {
    # Set compilation variables such as which compiler to use.
    #
    # Parameters:
    # $1: target architecture
    #
    # Returns:
    # 0: success
    # 1: failure
    supported_archs=("arm" "aarch64" "powerpc" "x86_64" "mips" "mipsel")

    local target_arch="$1"

    if [[ ! " ${supported_archs[@]} " =~ " ${target_arch} " ]]; then
        >&2 echo "Error: unsupported target architecture: $target_arch"
        return 1
    fi

    if [[ -n "$CURRENT_COMPILATION_VARIABLE_ARCH" && "$CURRENT_COMPILATION_VARIABLE_ARCH" == "$target_arch" ]]; then
        return 0
    fi

    >&2 fancy_title "Setting compilation variables for $target_arch"

    if [[ "$target_arch" == "arm" ]]; then
        CROSS=arm-linux-gnueabi-
        export HOST=arm-linux-gnueabi
    elif [[ "$target_arch" == "aarch64" ]]; then
        CROSS=aarch64-linux-gnu-
        export HOST=aarch64-linux-gnu
    elif [[ "$target_arch" == "powerpc" ]]; then
        CROSS=powerpc-linux-gnu-
        export HOST=powerpc-linux-gnu
    elif [[ "$target_arch" == "mips" ]]; then
        CROSS=mips-linux-gnu-
        export HOST=mips-linux-gnu
    elif [[ "$target_arch" == "mipsel" ]]; then
        CROSS=mipsel-linux-gnu-
        export HOST=mipsel-linux-gnu
    elif [[ "$target_arch" == "x86_64" ]]; then
        CROSS=x86_64-linux-gnu-
        export HOST=x86_64-linux-gnu
    fi

    export CC="${CROSS}gcc"
    export CXX="${CROSS}g++"

    export CFLAGS="-O2"
    export CXXFLAGS="-O2"

    # Strip the binary to reduce it's size.
    export LDFLAGS="-s"

    export CURRENT_COMPILATION_VARIABLE_ARCH="$target_arch"
}

function set_up_lib_search_paths() {
    # Set up library-related linker search paths.
    #
    # Parameters:
    # $1: ncursesw build dir
    # $2: libexpat build dir
    local ncursesw_build_dir="$1"
    local libexpat_build_dir="$2"

    # I) Allow tui mode by adding our custom built static ncursesw library to the linker search path.
    # II) Allow parsing xml files by adding libexpat library to the linker search path.
    export LDFLAGS="-L$ncursesw_build_dir/lib -L$libexpat_build_dir/lib/.libs $LDFLAGS"
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

    >&2 fancy_title "Building libiconv for $target_arch"

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

    >&2 fancy_title "Finished building libiconv for $target_arch"

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

    >&2 fancy_title "Building libgmp for $target_arch"

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

    >&2 fancy_title "Finished building libgmp for $target_arch"

    popd > /dev/null
}

function build_ncurses() {
    # Build libncursesw.
    #
    # Parameters:
    # $1: libncursesw package directory
    # $2: target architecture
    #
    # Echoes:
    # The libncursesw build directory
    #
    # Returns:
    # 0: success
    # 1: failure
    local ncurses_dir="$1"
    local target_arch="$2"
    local ncurses_build_dir="$(realpath "$ncurses_dir/build-$target_arch")"

    echo "$ncurses_build_dir"
    mkdir -p "$ncurses_build_dir"

    if [[ -f "$ncurses_build_dir/lib/libncursesw.a" ]]; then
        >&2 echo "Skipping build: libncursesw already built for $target_arch"
        return 0
    fi

    pushd "$ncurses_build_dir" > /dev/null

    >&2 fancy_title "Building libncursesw for $target_arch"

    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" "--enable-widec" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building libncursesw for $target_arch"

    popd > /dev/null
}

function build_libexpat() {
    # Build libexpat.
    #
    # Parameters:
    # $1: libexpat package directory
    # $2: target architecture
    #
    # Echoes:
    # The libexpat build directory
    #
    # Returns:
    # 0: success
    # 1: failure
    local libexpat_dir="$1"
    local target_arch="$2"
    local libexpat_build_dir="$(realpath "$libexpat_dir/build-$target_arch")"

    echo "$libexpat_build_dir"
    mkdir -p "$libexpat_build_dir"

    if [[ -f "$libexpat_build_dir/lib/.libs/libexpat.a" ]]; then
        >&2 echo "Skipping build: libexpat already built for $target_arch"
        return 0
    fi

    pushd "$libexpat_build_dir" > /dev/null

    >&2 fancy_title "Building libexpat for $target_arch"

    # Generate configure if it doesnt exist.
    if [[ ! -f "$libexpat_build_dir/../expat/configure" ]]; then
        >&2 ../expat/buildconf.sh ../expat/
    fi

    ../expat/configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building libexpat for $target_arch"

    popd > /dev/null
}

function build_python() {
    # Build python.
    #
    # Parameters:
    # $1: python package directory
    # $2: target architecture
    # $3: gdb's python module directory parent
    # $4: pygment's toplevel source dir.
    #
    # Echoes:
    # The python build directory
    #
    # Returns:
    # 0: success
    # 1: failure
    local python_dir="$1"
    local target_arch="$2"
    local gdb_python_parent="$3"
    local pygments_source_dir="$4"
    local python_lib_dir="$(realpath "$python_dir/build-$target_arch")"

    echo "$python_lib_dir"
    mkdir -p "$python_lib_dir"

    # Having a python-config file is an indication that we successfully built python.
    if [[ -f "$python_lib_dir/python-config" ]]; then
        >&2 echo "Skipping build: libpython already built for $target_arch"
        return 0
    fi

    pushd "$python_lib_dir" > /dev/null
    >&2 fancy_title "Building python for $target_arch"

    export LINKFORSHARED=" "
    export MODULE_BUILDTYPE="static"
    export CONFIG_SITE="$python_dir/config.site-static"
    >&2 CFLAGS="-static" LDFLAGS="-static" ../configure \
        --prefix=$(realpath .) \
        --disable-test-modules \
        --with-ensurepip=no \
        --without-decimal-contextvar \
        --build=x86_64-pc-linux-gnu \
        --host=$HOST \
        --with-build-python=/usr/bin/python3.12 \
        --disable-ipv6 \
        --disable-shared

    # Extract the regular standard library modules that are to be frozen and include the gdb and pygments custom libraries.
    export EXTRA_FROZEN_MODULES="$(printf "%s" "$(< ${script_dir}/frozen_python_modules.txt)" | tr $'\n' ";")"
    export EXTRA_FROZEN_MODULES="${EXTRA_FROZEN_MODULES};<gdb.**.*>: gdb = ${gdb_python_parent};<pygments.**.*>: pygments = ${pygments_source_dir}"
    >&2 echo "Frozen Modules: ${EXTRA_FROZEN_MODULES}"

    # Regenerate frozen modules with gdb env varaible. Do it after the configure because we need
    # the `regen-frozen` makefile.
    >&2 python3.12 ../Tools/build/freeze_modules.py
    >&2 make regen-frozen

    # Build python after configuring the project and regnerating frozen files.
    >&2 make -j $(nproc)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Install python (in build dir using the prefix set above), in order to have a bash (for cross-compilation) python3-config that works.
    >&2 make install
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building python for $target_arch"
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

    >&2 fancy_title "Building libmpfr for $target_arch"

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

    >&2 fancy_title "Finished building libmpfr for $target_arch"

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
    # $6: whether to build with python or not
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
    local with_python="$6"

    if [[ "$with_python" == "yes" ]]; then
        local python_flag="--with-python=/app/gdb/build/packages/cpython-static/build-$target_arch/bin/python3-config"
        local gdb_build_dir="$(realpath "$gdb_dir/build-${target_arch}_with_python")"
    else
        local python_flag="--without-python"
        local gdb_build_dir="$(realpath "$gdb_dir/build-${target_arch}")"
    fi

    echo "$gdb_build_dir"
    mkdir -p "$gdb_build_dir"

    if [[ -f "$gdb_build_dir/gdb/gdb" ]]; then
        >&2 echo "Skipping build: gdb already built for $target_arch"
        return 0
    fi

    pushd "$gdb_build_dir" > /dev/null

    >&2 fancy_title "Building gdb for $target_arch"

    ../configure -C --enable-static --with-static-standard-libraries --disable-inprocess-agent \
                 --enable-tui "$python_flag" \
                 --with-expat --with-libexpat-type="static" \
                 --with-gdb-datadir="/usr/share/gdb" --with-separate-debug-dir="/usr/lib/debug" \
                 --with-system-gdbinit="/etc/gdb/gdbinit" --with-system-gdbinit-dir="/etc/gdb/gdbinit.d" \
                 --with-jit-reader-dir="/usr/lib/gdb" \
                 "--with-libiconv-prefix=$libiconv_prefix" --with-libiconv-type=static \
                 "--with-gmp=$libgmp_prefix" \
                 "--with-mpfr=$libmpfr_prefix" \
                 "CC=$CC" "CXX=$CXX" "LDFLAGS=$LDFLAGS" "--host=$HOST" \
                 "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building gdb for $target_arch"

    popd > /dev/null
}

function install_gdb() {
    # Install gdb binaries to an artifacts directory.
    #
    # Parameters:
    # $1: gdb build directory
    # $2: artifacts directory
    # $3: target architecture
    # $4: whether gdb was built with or without python
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_build_dir="$1"
    local artifacts_dir="$2"
    local target_arch="$3"
    local with_python="$4"

    if [[ "$with_python" == "yes" ]]; then
        local artifacts_location="$artifacts_dir/${target_arch}_with_python"
    else
        local artifacts_location="$artifacts_dir/${target_arch}"
    fi

    if [[ -d "$artifacts_location" && -n "$(ls -A "$artifacts_location")" ]]; then
        >&2 echo "Skipping install: gdb already installed for $target_arch"
        return 0
    fi

    temp_artifacts_dir="$(mktemp -d)"

    mkdir -p "$artifacts_location"

    make -C "$gdb_build_dir" install "DESTDIR=$temp_artifacts_dir" 1>&2
    if [[ $? -ne 0 ]]; then
        rm -rf "$temp_artifacts_dir"
        return 1
    fi

    while read file; do
        cp "$file" "$artifacts_location/"
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
    # $5: whether to build with python or not
    # $6: install directory
    # $7: target architecture
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_dir="$1"
    local libiconv_prefix="$2"
    local libgmp_prefix="$3"
    local libmpfr_prefix="$4"
    local with_python="$5"
    local artifacts_dir="$6"
    local target_arch="$7"

    gdb_build_dir="$(build_gdb "$gdb_dir" "$target_arch" "$libiconv_prefix" "$libgmp_prefix" "$libmpfr_prefix" "$with_python")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    install_gdb "$gdb_build_dir" "$artifacts_dir" "$target_arch" "$with_python"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
}

function build_gdb_dependencies() {
    # Build gdb dependencies for a specific target architecture.
    # NOTE: Dependencies doesn't inlcude python.
    #
    # Parameters:
    # $1: target architecture
    # $2: build directory

    local target_arch="$1"
    local build_dir="$2"

    set_compliation_variables "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    mkdir -p "$build_dir"

    export ICONV_BUILD_DIR="$(build_iconv "$build_dir/libiconv" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    export GMP_BUILD_DIR="$(build_libgmp "$build_dir/gmp" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    export MPFR_BUILD_DIR="$(build_libmpfr "$build_dir/mpfr" "$GMP_BUILD_DIR" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    export NCURSESW_BUILD_DIR="$(build_ncurses "$build_dir/ncurses" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    export LIBEXPAT_BUILD_DIR="$(build_libexpat "$build_dir/libexpat" "$target_arch")"
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
    # $3: src directory
    # $4: whether to build gdb with python or not

    local target_arch="$1"
    local build_dir="$2"
    local source_dir="$3"
    local with_python="$4"
    local packages_dir="$build_dir/packages"
    local artifacts_dir="$build_dir/artifacts"

    set_compliation_variables "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    mkdir -p "$packages_dir"

    build_gdb_dependencies "$target_arch" "$packages_dir"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    set_up_lib_search_paths "$NCURSESW_BUILD_DIR" "$LIBEXPAT_BUILD_DIR"

    if [[ "$with_python" == "yes" ]]; then
        local gdb_python_dir="$packages_dir/binutils-gdb/gdb/python/lib/"
        local pygments_source_dir="$packages_dir/pygments/"
        local python_build_dir="$(build_python "$packages_dir/cpython-static" "$target_arch" "$gdb_python_dir" "$pygments_source_dir")"
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi

    build_and_install_gdb "$packages_dir/binutils-gdb" \
                          "$ICONV_BUILD_DIR/lib/.libs/" \
                          "$GMP_BUILD_DIR/.libs/" \
                          "$MPFR_BUILD_DIR/src/.libs/" \
                          "$with_python" \
                          "$artifacts_dir" \
                          "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
}

function main() {
    if [[ $# -lt 3 ]]; then
        >&2 echo "Usage: $0 <target_arch> <build_dir> <src_dir> [--with-python | --common-only]"
        exit 1
    fi

    local with_python="no"
    local common_only="no"

    for arg in "$@"; do
        case "$arg" in
            --with-python)
                if [[ "$common_only" == "yes" ]]; then
                    >&2 echo "Error: --with-python and --common-only are mutually exclusive"
                    exit 1
                fi
                with_python="yes"
                ;;
            --common-only)
                if [[ "$with_python" == "yes" ]]; then
                    >&2 echo "Error: --with-python and --common-only are mutually exclusive"
                    exit 1
                fi
                common_only="yes"
                ;;
        esac
    done

    if [[ "$common_only" == "yes" ]]; then
        build_gdb_dependencies "$1" "$2/packages"
        if [[ $? -ne 0 ]]; then
            >&2 echo "Error: failed to build common dependencies"
            exit 1
        fi
        exit 0
    fi

    build_gdb_with_dependencies "$1" "$2" "$3" "$with_python"
    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to build gdb with dependencies"
        exit 1
    fi
}

main "$@"
