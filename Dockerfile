FROM ubuntu:24.04

# Install dependencies
RUN apt update && apt install -y \
    g++ \
    gcc \
    m4  \
    make \
    patch \
    texinfo \
    wget \
    xz-utils

# Build iconv
WORKDIR /tmp
RUN wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz
RUN tar -xvf libiconv-1.17.tar.gz
WORKDIR /tmp/libiconv-1.17/build
RUN ../configure --enable-static
RUN make -j $((`nproc`+1))
RUN cp -r ./include ./lib/.libs/
RUN mkdir ./lib/.libs/lib/
RUN cp ./lib/.libs/libiconv.a ./lib/.libs/lib/

# Build libgmp
WORKDIR /tmp
RUN wget https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz
RUN tar -xvf gmp-6.3.0.tar.xz
WORKDIR /tmp/gmp-6.3.0/build
RUN ../configure --enable-static
RUN make -j $((`nproc`+1))
RUN mkdir ./.libs/include/
RUN cp gmp.h ./.libs/include/
RUN mkdir ./.libs/lib/
RUN cp ./.libs/libgmp.a ./.libs/lib/

# Build libmpfr
WORKDIR /tmp
RUN wget https://www.mpfr.org/mpfr-current/mpfr-4.2.1.tar.xz
RUN tar -xvf mpfr-4.2.1.tar.xz
WORKDIR /tmp/mpfr-4.2.1/build
RUN ../configure --enable-static --with-gmp-build=/tmp/gmp-6.3.0/build
RUN make -j $((`nproc`+1))
RUN mkdir ./src/.libs/include
RUN cp /tmp/mpfr-4.2.1/src/mpfr.h ./src/.libs/include/
RUN mkdir ./src/.libs/lib
RUN cp ./src/.libs/libmpfr.a ./src/.libs/lib/

# Build gdb
WORKDIR /tmp
RUN wget https://ftp.gnu.org/gnu/gdb/gdb-15.1.tar.xz
RUN tar -xvf gdb-15.1.tar.xz
COPY gdb_static.patch /tmp/gdb-15.1/
WORKDIR /tmp/gdb-15.1
RUN patch -p1 < gdb_static.patch
WORKDIR /tmp/gdb-15.1/build
RUN ../configure --enable-static --with-static-standard-libraries --disable-tui --disable-inprocess-agent --with-libiconv-prefix=/tmp/libiconv-1.17/build/lib/.libs/ --with-libiconv-type=static --with-gmp=/tmp/gmp-6.3.0/build/.libs/ --with-mpfr=/tmp/mpfr-4.2.1/build/src/.libs/
RUN make -j $((`nproc`+1))

# Copy the generated files
RUN mkdir /gdb
RUN make install DESTDIR=/gdb
