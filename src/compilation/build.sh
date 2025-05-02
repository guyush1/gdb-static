#!/bin/bash

# Include utils library
script_dir=$(dirname "$0")
source "$script_dir/utils.sh"
source "$script_dir/full_build_conf.sh"

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

    >&2 fancy_title "Setting compilation variables for $target_arch"

    if [[ "$target_arch" == "arm" ]]; then
        CROSS=arm-linux-musleabi-
        export HOST=arm-linux-musleabi
    elif [[ "$target_arch" == "aarch64" ]]; then
        CROSS=aarch64-linux-musl-
        export HOST=aarch64-linux-musl
    elif [[ "$target_arch" == "powerpc" ]]; then
        CROSS=powerpc-linux-musl-
        export HOST=powerpc-linux-musl
    elif [[ "$target_arch" == "mips" ]]; then
        CROSS=mips-linux-musl-
        export HOST=mips-linux-musl
    elif [[ "$target_arch" == "mipsel" ]]; then
        CROSS=mipsel-linux-musl-
        export HOST=mipsel-linux-musl
    elif [[ "$target_arch" == "x86_64" ]]; then
        CROSS=x86_64-linux-musl-
        export HOST=x86_64-linux-musl
    fi

    export CC="${CROSS}gcc"
    export CXX="${CROSS}g++"

    export CFLAGS="-Os"
    export CXXFLAGS="-Os"

    # Strip the binary to reduce it's size.
    export LDFLAGS="-s"
}

function set_up_lib_search_path() {
    # Set up library-related linker search paths.
    #
    # Parameters:
    # $1: library install dir
    # $2: whether to add linker search path or not (include path is always added).
    local lib_install_dir="$1"
    local add_linker_include_path="$2"

    if [[ $add_linker_include_path == 1 ]]; then
        # Add library to the linker's include path.
        export LDFLAGS="-L$lib_install_dir/lib $LDFLAGS"
    fi

    # Add library standard headers to the CC / CXX flags.
    local include_paths="-I$lib_install_dir/include"
    export CC="$CC $include_paths"
    export CXX="$CXX $include_paths"
}

function set_up_base_lib_search_paths() {
    # Set up library-related linker search paths.
    #
    # Parameters:
    # $1: iconv build dir
    # $2: gmp build dir
    # $3: mpfr build dir
    # $4: ncursesw build dir
    # $5: expat build dir
    local iconv_build_dir="$1"
    local gmp_build_dir="$2"
    local mpfr_build_dir="$3"
    local ncursesw_build_dir="$4"
    local expat_build_dir="$5"

    set_up_lib_search_path $iconv_build_dir 0
    set_up_lib_search_path $gmp_build_dir 0
    set_up_lib_search_path $mpfr_build_dir 0
    set_up_lib_search_path $ncursesw_build_dir 1
    set_up_lib_search_path $expat_build_dir 1
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

    if [[ -f "$iconv_build_dir/lib/libiconv.a" ]]; then
        >&2 echo "Skipping build: iconv already built for $target_arch"
        return 0
    fi

    pushd "$iconv_build_dir" > /dev/null

    >&2 fancy_title "Building libiconv for $target_arch"

    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" --prefix="$(realpath .)" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) install 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building libiconv for $target_arch"

    popd > /dev/null
}

function build_lzma() {
    # Build liblzma.
    #
    # Parameters:
    # $1: lzma package directory
    # $2: target architecture
    #
    # Echoes:
    # The lzma build directory
    #
    # Returns:
    # 0: success
    # 1: failure

    local lzma_dir="$1"
    local target_arch="$2"
    local lzma_build_dir="$(realpath "$lzma_dir/build-$target_arch")"

    echo "$lzma_build_dir"
    mkdir -p "$lzma_build_dir"

    if [[ -f "$lzma_build_dir/lib/liblzma.a" ]]; then
        >&2 echo "Skipping build: lzma already built for $target_arch"
        return 0
    fi

    pushd "$lzma_build_dir" > /dev/null

    >&2 fancy_title "Building liblzma for $target_arch"

    # Make sure configure exists by running autogen.sh
    (
        cd .. && ./autogen.sh 1>&2
    )

    # lzma's autoconf contains a bug, it's instal prefix is relative
    # to the current build directory.
    # Hence, we set the prefix here to "/" instead of realpath . .
    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" --prefix="/" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) install DESTDIR=$lzma_build_dir 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building liblzma for $target_arch"

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

    if [[ -f "$gmp_build_dir/lib/libgmp.a" ]]; then
        >&2 echo "Skipping build: libgmp already built for $target_arch"
        return 0
    fi

    pushd "$gmp_build_dir" > /dev/null

    >&2 fancy_title "Building libgmp for $target_arch"

    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" --prefix="$(realpath .)" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) install 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

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

    # ncurses needs a custom install dir due to it's non-standard compilation directories.
    local ncurses_install_dir="$ncurses_build_dir/output"

    echo "$ncurses_install_dir"
    mkdir -p "$ncurses_install_dir"

    if [[ -f "$ncurses_install_dir/lib/libncursesw.a" ]]; then
        >&2 echo "Skipping build: libncursesw already built for $target_arch"
        return 0
    fi

    pushd "$ncurses_build_dir" > /dev/null

    >&2 fancy_title "Building libncursesw for $target_arch"

    ../configure --enable-static "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" "--enable-widec" \
        --prefix="$ncurses_install_dir" --with-default-terminfo-dir="/usr/share/terminfo"  1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Install the include & library dirs, but not the terminfo database.
    # The user is responsible for supplying the terminal database.
    make -j$(nproc) install.includes install.libs 1>&2
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

    if [[ -f "$libexpat_build_dir/lib/libexpat.a" ]]; then
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
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" --prefix="$(realpath .)" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) install 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building libexpat for $target_arch"

    popd > /dev/null
}

function build_libffi() {
    # Build libffi, for the ctypes python module.
    #
    # Parameters:
    # $1: libffi package directory
    # $2: Target architecture
    local libffi_dir="$1"
    local target_arch="$2"

    pushd "${libffi_dir}" > /dev/null

    local libffi_build_dir="$(realpath "$libffi_dir/build-$target_arch")"

    # libffi needs a custom install dir due to it's non-standard compilation directories.
    local libffi_install_dir="$libffi_build_dir/output"
    echo "${libffi_install_dir}"

    # Creates both the installation and build dirs because install is in build.
    mkdir -p "${libffi_install_dir}"

    if [[ -f "$libffi_install_dir/lib/libffi.a" ]]; then
        >&2 echo "Skipping build: libffi already built for $target_arch"
        return 0
    fi

    >&2 ./autogen.sh
    pushd "${libffi_build_dir}" > /dev/null

    >&2 fancy_title "Building libffi for $target_arch"

    >&2 CFLAGS="${CFLAGS} -DNO_JAVA_RAW_API" ../configure \
        --enable-silent-rules \
        --enable-static \
        --disable-shared \
        --disable-docs \
        --prefix="${libffi_install_dir}"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 make -j$(nproc)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 make -j$(nproc) install
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 fancy_title "Finished building libffi for $target_arch"

    popd > /dev/null
    popd > /dev/null
}

function add_to_pkg_config_path() {
    # This method add directories to the list that pkg-config looks for .pc (package config) files
    # when finding the correct flags for modules.
    #
    # Parameters:
    # $1: The directory to add to the package-config path.
    local new_pkg_config_dir="${1}"

    if [[ -n "${PKG_CONFIG_PATH}" ]]; then
        export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${new_pkg_config_dir}"
    else
        export PKG_CONFIG_PATH="${new_pkg_config_dir}"
    fi
}

function setup_libffi_env() {
    # We need a valid pkg-config file for libffi in order for Python to recognize the package and
    # know that it exists. Because we a pkg-config file, we might as well use it in order to ensure
    # that we get the correct flags instead of manually typing them.
    # Becuase of this, the setup of libffi isn't done in set_up_lib_search_path, as we don't need it.
    #
    # Parameters:
    # $1: Libffi installation dir
    local libffi_install_dir="$1"

    # Needed because this is how Python recognizes the available packages.
    add_to_pkg_config_path "${libffi_install_dir}/lib/pkgconfig/"

    # If we have a pc file, might as well use it.
    local libffi_cflags="$(pkg-config --cflags libffi)"
    local libffi_libs="$(pkg-config --libs --static libffi)"

    export CC="${CC} ${libffi_cflags}"
    export CXX="${CXX} ${libffi_cflags}"

    export LDFLAGS="${libffi_libs} ${LDFLAGS}"
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
        --prefix="$(realpath .)" \
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
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    >&2 make regen-frozen
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Build python after configuring the project and regnerating frozen files.
    >&2 make -j$(nproc)
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

    if [[ -f "$mpfr_build_dir/lib/libmpfr.a" ]]; then
        >&2 echo "Skipping build: libmpfr already built for $target_arch"
        return 0
    fi

    pushd "$mpfr_dir/build-$target_arch" > /dev/null

    >&2 fancy_title "Building libmpfr for $target_arch"

    ../configure --enable-static --prefix="$(realpath .)" "--with-gmp=$libgmp_build_dir" \
        "CC=$CC" "CXX=$CXX" "--host=$HOST" \
        "CFLAGS=$CFLAGS" "CXXFLAGS=$CXXFLAGS" 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    make -j$(nproc) install 1>&2
    if [[ $? -ne 0 ]]; then
        return 1
    fi

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
    # $6: liblzma prefix
    # $7: build mode: slim / full.
    # $8: gdb cross-architecture binary format support formats (relevant for full builds only).
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
    local liblzma_prefix="$6"
    local full_build="$7"
    local gdb_bfd_archs="$8"

    local extra_flags=()
    if [[ "$full_build" == "yes" ]]; then
        if [[ $full_build_cross_arch_debugging -eq 1 ]]; then
            extra_flags+=("--enable-targets=$gdb_bfd_archs" "--enable-64-bit-bfd" "--disable-sim")
        fi

        if [[ $full_build_python_support -eq 1 ]]; then
            extra_flags+=("--with-python=/app/gdb/build/packages/cpython-static/build-$target_arch/bin/python3-config")
        else
            extra_flags+=("--without-python")
        fi

        local gdb_build_dir="$(realpath "$gdb_dir/build-${target_arch}-full")"
    else
        extra_flags+=("--without-python")
        local gdb_build_dir="$(realpath "$gdb_dir/build-${target_arch}-slim")"
    fi

    echo "$gdb_build_dir"
    mkdir -p "$gdb_build_dir"

    if [[ -f "$gdb_build_dir/gdb/gdb" ]]; then
        >&2 echo "Skipping build: gdb already built for $target_arch"
        return 0
    fi

    pushd "$gdb_build_dir" > /dev/null

    >&2 fancy_title "Building gdb for $target_arch"

    ../configure --enable-static --with-static-standard-libraries --disable-inprocess-agent \
                 --with-gdb-datadir="/usr/share/gdb" --with-separate-debug-dir="/usr/lib/debug" \
                 --with-system-gdbinit="/etc/gdb/gdbinit" --with-system-gdbinit-dir="/etc/gdb/gdbinit.d" \
                 --with-jit-reader-dir="/usr/lib/gdb" \
                 --with-libiconv-prefix="$libiconv_prefix" --with-libiconv-type=static \
                 --with-gmp="$libgmp_prefix" \
                 --with-mpfr="$libmpfr_prefix" \
                 --enable-tui \
                 --with-expat --with-libexpat-type=static \
                 --with-lzma=yes --with-liblzma-prefix="$liblzma_prefix" --with-liblzma-type="static" \
                 "${extra_flags[@]}" \
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
    # $4: build mode: slim / full.
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_build_dir="$1"
    local artifacts_dir="$2"
    local target_arch="$3"
    local full_build="$4"

    if [[ "$full_build" == "yes" ]]; then
        local artifacts_location="$artifacts_dir/${target_arch}_full"
    else
        local artifacts_location="$artifacts_dir/${target_arch}_slim"
    fi

    if [[ -d "$artifacts_location" && -n "$(ls -A "$artifacts_location")" ]]; then
        >&2 echo "Skipping install: gdb already installed for $target_arch"
        return 0
    fi

    temp_artifacts_dir="$(mktemp -d)"

    mkdir -p "$artifacts_location"

    make -j$(nproc) -C "$gdb_build_dir" install "DESTDIR=$temp_artifacts_dir" 1>&2
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
    # $5: liblzma prefix.
    # $6: build mode: slim / full.
    # $7: gdb cross-architecture binary format support formats (relevant for full builds only).
    # $8: install directory
    # $9: target architecture
    #
    # Returns:
    # 0: success
    # 1: failure

    local gdb_dir="$1"
    local libiconv_prefix="$2"
    local libgmp_prefix="$3"
    local libmpfr_prefix="$4"
    local liblzma_prefix="$5"
    local full_build="$6"
    local gdb_bfd_archs="$7"
    local artifacts_dir="$8"
    local target_arch="$9"

    gdb_build_dir="$(build_gdb "$gdb_dir" "$target_arch" "$libiconv_prefix" "$libgmp_prefix" "$libmpfr_prefix" "$liblzma_prefix" "$full_build" "$gdb_bfd_archs")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    install_gdb "$gdb_build_dir" "$artifacts_dir" "$target_arch" "$full_build"
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
    # $4: build mode: slim / full.
    # $5: gdb cross-architecture binary format support formats (relevant for full builds only).

    local target_arch="$1"
    local build_dir="$2"
    local source_dir="$3"
    local full_build="$4"
    local gdb_bfd_archs="$5"
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

    ncursesw_build_dir="$(build_ncurses "$packages_dir/ncurses" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    libexpat_build_dir="$(build_libexpat "$packages_dir/libexpat" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    lzma_build_dir="$(build_lzma "$packages_dir/xz" "$target_arch")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi 

    set_up_base_lib_search_paths "$iconv_build_dir" \
                                 "$gmp_build_dir" \
                                 "$mpfr_build_dir" \
                                 "$ncursesw_build_dir" \
                                 "$libexpat_build_dir"

    # Optional build components
    if [[ $full_build == "yes" && $full_build_python_support -eq 1 ]]; then
        local libffi_install_dir="$(build_libffi "${packages_dir}/libffi" "${target_arch}")"
        setup_libffi_env "${libffi_install_dir}"

        local gdb_python_dir="$packages_dir/binutils-gdb/gdb/python/lib/"
        local pygments_source_dir="$packages_dir/pygments/"
        local python_build_dir="$(build_python "$packages_dir/cpython-static" "$target_arch" "$gdb_python_dir" "$pygments_source_dir")"
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi

    build_and_install_gdb "$packages_dir/binutils-gdb" \
                          "$iconv_build_dir" \
                          "$gmp_build_dir" \
                          "$mpfr_build_dir" \
                          "$lzma_build_dir" \
                          "$full_build" \
                          "$gdb_bfd_archs" \
                          "$artifacts_dir" \
                          "$target_arch"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
}

function main() {
    if [[ $# -lt 4 ]]; then
        >&2 echo "Usage: $0 <target_arch> <build_dir> <src_dir> <slim/full> [gdb-bfd-archs]"
        exit 1
    fi

    local full_build="no"
    if [[ "$4" == "full" ]]; then
        full_build="yes"
    else
        full_build="no"
    fi

    build_gdb_with_dependencies "$1" "$2" "$3" "$full_build" "$5"
    if [[ $? -ne 0 ]]; then
        >&2 echo "Error: failed to build gdb with dependencies"
        exit 1
    fi
}

main "$@"
