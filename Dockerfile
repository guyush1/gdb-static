FROM ubuntu:24.04

RUN apt update

RUN apt install -y \
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
    python3-pip \
    libpython3-dev \
    texinfo \
    wget \
    xz-utils

# Remove externally-managed constrainsts since we run inside a docker...
RUN rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED
RUN python3.12 -m pip install requests

COPY src/docker_utils/download_musl_toolchains.py .
RUN python3.12 -u download_musl_toolchains.py

WORKDIR /app/gdb

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
