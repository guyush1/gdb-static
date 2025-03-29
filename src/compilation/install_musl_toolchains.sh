#!/bin/bash
set -e

# Define architectures and their respective musl toolchain URLs.
ARCHS=("x86_64" "arm" "aarch64" "powerpc" "mips" "mipsel")
BASE_URL="https://musl.cc"

if [[ -z "$MUSL_INSTALL_DIR" ]]; then
    echo "MUSL_INSTALL_DIR variable has not been set!"
    exit 1
fi

# Create install directory.
mkdir -p "$MUSL_INSTALL_DIR"
cd "$MUSL_INSTALL_DIR"

# Download and extract each toolchain.
for ARCH in "${ARCHS[@]}"; do
    TOOLCHAIN_TAR="${ARCH}-linux-musl-cross.tgz"

    # Arm has a non-generic special toolchain name :(.
    if [[ "$ARCH" == "arm" ]]; then
        TOOLCHAIN_TAR="arm-linux-musleabi-cross.tgz"
    fi

    URL="$BASE_URL/$TOOLCHAIN_TAR"

    echo "Downloading $URL..."
    wget -q --show-progress "$URL"

    echo "Extracting $TOOLCHAIN_TAR..."
    tar -xzf "$TOOLCHAIN_TAR"
    rm "$TOOLCHAIN_TAR"
done

# Add the installed toolchains to the PATH.
echo "Updating PATH..."
MUSL_PATHS=""
for dir in /opt/musl-cross/*/bin; do
    MUSL_PATHS="$dir:$MUSL_PATHS"
done

echo "PATH=$MUSL_PATHS:$PATH" >> ~/.bashrc
