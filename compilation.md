# Notes about this file - read before proceeding!

While we have already provided the gdb/gdbserver statically compiled binaries for you, some people might want to compile it without our build scripts, or compile a newer version of gdb in the future :).
The rest of the file contains a documentation of the compilation process, in order to help you out.

NOTE: The compilation guide describes the compilation process in order to create a minimal-working version of gdb. Our build-scripts also provides further capabilites to gdb, such as python and xml support, which are not documented in this file. 

## <VARAIBLES> In this file

Environment variables are denoted by <...> throughout this file.

Please note that when specifying a compilation dir throughout the compilation process (via the <COMPILATION_DIR_PATH> environment variable), DO NOT use relative pathing, or special bash characters such as `~`. Relative pathing / special bash characters will not get parsed correctly!

Instead, always use absolute paths.

Examples to the <VARIABLES> throughout the script:
- <CROSS_COMPILER_C> - arm-linux-gnueabi-gcc
- <CROSS_COMPILER_CPP> - arm-linux-gnueabi-g++
- <HOST_NAME> - arm-linux-gnueabi
- <COMPILATION_DIR_PATH> - /home/username/projects/libgmp-x.y.z/build-arm/

Environment info:
- glibc version: 2.39-0ubuntu8.3 (NOTE: When i compiled gdb using an older glibc, such as the one i had in my ubuntu-20.04 machine, i received a segfault in gdb, so the libc version is important!).

# Compiling gdb statically to the host platform

## 1) Compiling iconv

While compiling iconv is not a must, the libc-provided iconv (a utility to convert between encodings) may fail on different architectures,
at least in my experience.
Thus, I recommended using a custom libiconv and compiling it into gdb.

Download the source from https://github.com/roboticslibrary/libiconv.git

Make sure to check out to a stable tag (in my case - v1.17).

Work according to the following steps:
1. run `./gitsub.sh pull`
2. run `./autogen.sh` to create the configure script from configure.sh.
3. create a build dir (e.g build), and then cd into it.
4. run `../configure --enable-static`
5. run `cp -r ./include ./lib/.libs/`
6. run `mkdir ./lib/.libs/lib/`
7. run `cp ./lib/.libs/libiconv.a ./lib/.libs/lib/`

## 2) Compiling gdb

Clone gdb from from my forked respository - https://github.com/guyush1/binutils-gdb/tree/gdb-static.

Make sure to check out to the **gdb-static** branch - this branch contains all of the changes i had to do to the build system in order for it to compile gdb statically.

Work according to the following steps:
1. create a build dir.
2. run `../configure --enable-static --with-static-standard-libraries --disable-tui --disable-inprocess-agent --with-libiconv-prefix=<COMPILATION_DIR_PATH>/lib/.libs/ --with-libiconv-type=static`
3. run `make all-gdb -j$(nproc)` - for gdbserver, run `make all-gdbserver -j$(nproc)`.

gdb will sit under gdb/gdb.
gdbserver will sit under gdbserver/gdbserver.

# Cross compiling gdb statically to other architectures.

Cross compiling gdb statically is a bit more complicated then regular static compilation. In order to cross compile gdb statically, we will need to compile libgmp and libmpfr as well as iconv.

## 1) Compiling iconv

Work according to the same process as described under the compilation to the host platform, aside from the configure script:
IV) run `../configure --enable-static CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --host=<HOST_NAME>`

## 2) Compiling libgmp

Download and extract the latest edition from https://gmplib.org/.
I used the 6.3.0 edition.

Work according to the following steps:
1. Create a build dir and cd into it.
2. run `../configure CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --enable-static --host=<HOST_NAME>`
3. run `make -j$(nproc)`
4. run `mkdir ./.libs/include/`
5. run `cp gmp.h ./.libs/include/`
6. run `mkdir ./.libs/lib`
7. run `cp ./.libs/libgmp.a ./.libs/lib`

## 3) Compiling libmpfr

Download and extract the latest edition from https://www.mpfr.org/.
I used the 4.2.1 edition.

Work according to the following steps:
1. Create a build dir and cd into it.
2. run `../configure CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --enable-static --with-gmp-build=<COMPILATION_DIR_PATH> --host=<HOST_NAME>`
3. run `make -j$(nproc)`
4. run `mkdir ./src/.libs/lib`
5. run `cp ./src/.libs/libmpfr.a ./src/.libs/lib`
6. run `mkdir ./src/.libs/include`
7. run `cp ../src/mpfr.h ./src/.libs/include/`

## 4) Compiling gdb

Work according to the same process as described under the compilation to the host platform, aside from the configure script:

2. run `../configure --enable-static --with-static-standard-libraries --disable-tui --disable-inprocess-agent --with-libiconv-prefix=<COMPILATION_DIR_PATH>/lib/.libs/ --with-libiconv-type=static --with-gmp=<COMPILATION_DIR_PATH>/.libs/ --with-mpfr=<COMPILATION_DIR_PATH>/src/.libs/ CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --host=<HOST_NAME>`
