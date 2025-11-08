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
    libpython3-dev \
    libtool \
    m4  \
    make \
    patch \
    pkg-config \
    python3-pip \
    software-properties-common \
    texinfo \
    wget \
    xz-utils

RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt update && apt install -y python3.14

# We require aiohttp >= 3.12 (For client middleware support), which is newer than the currently
# available python3-aiohttp's version in Ubuntu.
RUN python3.14 -m pip install --break-system-packages aiohttp

COPY src/docker_utils/download_musl_toolchains.py .
RUN python3.14 -u download_musl_toolchains.py

WORKDIR /app/gdb

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
