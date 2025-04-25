FROM ubuntu:24.04

RUN apt update && apt install -y \
    autopoint \
    binutils-multiarch \
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
    libtool \
    m4  \
    make \
    patch \
    pkg-config \
    python3.12 \
    python3-aiohttp \
    libpython3-dev \
    texinfo \
    wget \
    xz-utils

COPY src/docker_utils/download_musl_toolchains.py .
RUN python3.12 -u download_musl_toolchains.py

WORKDIR /app/gdb

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
