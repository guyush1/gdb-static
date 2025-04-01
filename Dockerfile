FROM ubuntu:24.04

# Install dependencies
RUN apt update && apt install -y \
    bison \
    file \
    flex \
    g++ \
    g++-aarch64-linux-gnu \
    g++-arm-linux-gnueabi \
    g++-mips-linux-gnu \
    g++-mipsel-linux-gnu \
    g++-powerpc-linux-gnu \
    gcc \
    gcc-aarch64-linux-gnu \
    gcc-arm-linux-gnueabi \
    gcc-mips-linux-gnu \
    gcc-mipsel-linux-gnu \
    gcc-powerpc-linux-gnu \
    git \
    libncurses-dev \
    libtool \
    m4  \
    make \
    patch \
    pkg-config \
    python3.12 \
    libpython3-dev \
    texinfo \
    wget \
    xz-utils

# Install musl-based toolchains.
ENV MUSL_INSTALL_DIR="/usr/"
COPY src/compilation/install_musl_toolchains.sh .
RUN ./install_musl_toolchains.sh

WORKDIR /app/gdb
