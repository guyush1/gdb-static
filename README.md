# Repository of static gdb and gdbserver

The statically compiled gdb / gdbserver binaries are avaliable to download under github releases! 

# Notes about this file - read before proceeding!

While i already provided the gdb/gdbserver-15 statically compiled binaries handed out to you, some people might want to compile it to a different architecture, or compile a newer version of gdb in the future :). This rest of the file contains my compilation documentation so that you could save yourself some time and do it yourself, if you wish.

## <VARAIBLES> in the script

When specifying the compilation dir throughout the compilation process (specified as <COMPILATION_DIR_PATH> in this file), DO NOT use relative pathing, or bash characters such as `~`. They will not get parsed correctly! Instead, use absolute paths only.

Examples to the <VARIABLES> throughout the script:
<CROSS_COMPILER_C> - arm-linux-gnueabi-gcc
<CROSS_COMPILER_CPP> - arm-linux-gnueabi-g++
<HOST_NAME> - arm-linux-gnueabi
<COMPILATION_DIR_PATH> - /home/username/projects/libgmp-x.y.z/build-arm/

Environment info:
- glibc version: 2.39-0ubuntu8.3 (NOTE: When i compiled gdb-15 using an older glibc, such as the one i had in my ubuntu-20.04 machine, i received a segfault in gdb...).

# Compiling gdb statically to the host platform

## 1) Compiling iconv

While compiling iconv is not a must, the libc-provided iconv (a utility to convert between encodings) may fail on different architectures,
at least in my experiance. Thus, I recommended using a custom libiconv and compiling it into gdb.

Download the source from https://github.com/roboticslibrary/libiconv.git
Make sure to check out to a stable tag (in my case - v1.17).

Work according to the following steps:
I) run `./gitsub.sh pull`
II) run `./autogen.sh` to create the configure script from configure.sh.
III) create a build dir (e.g build), and then cd into it.
IV) run `../configure --enable-static`
V) run `cp -r ./include ./lib/.libs/`
VI) run `mkdir ./lib/.libs/lib/`
VII) run `cp ./lib/.libs/libiconv.a ./lib/.libs/lib/`

## 2) Compiling gdb

Clone gdb from sourceware - https://sourceware.org/git/binutils-gdb.git.
I checked out to the 15.1 tag.

Work according to the following steps:
I) Apply my patches (gdb_static.patch). If you are not on the exact tag i used (15.1) - you might need to apply them manually, and change some stuff.
II) create a build dir.
III) run `../configure --enable-static --with-static-standard-libraries --disable-tui --disable-inprocess-agent --with-libiconv-prefix=<COMPILATION_DIR_PATH>/lib/.libs/ --with-libiconv-type=static`
IV) run `make all-gdb -j$(nproc)` - for gdbserver, run `make all-gdbserver -j$(nproc)`.

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
I) Create a build dir and cd into it.
II) run `../configure CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --enable-static --host=<HOST_NAME>`
III) run `make -j$(nproc)`
IV) run `mkdir ./.libs/include/`
V) run `cp gmp.h ./.libs/include/`
VI) run `mkdir ./.libs/lib`
VII) run `cp ./.libs/libgmp.a ./.libs/lib`

## 3) Compiling libmpfr

Download and extract the latest edition from https://www.mpfr.org/.
I used the 4.2.1 edition.

Work according to the following steps:
I) Create a build dir and cd into it.
II) run `../configure CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --enable-static --with-gmp-build=<COMPILATION_DIR_PATH> --host=<HOST_NAME>`
III) run `make -j$(nproc)`
IV) run `mkdir ./src/.libs/lib`
V) run `cp ./src/.libs/libmpfr.a ./src/.libs/lib`
VI) run `mkdir ./src/.libs/include`
VII) run `cp ../src/mpfr.h ./src/.libs/include/`

## 4) Compiling gdb

Work according to the same process as described under the compilation to the host platform, aside from the configure script:
III) run `../configure --enable-static --with-static-standard-libraries --disable-tui --disable-inprocess-agent --with-libiconv-prefix=<COMPILATION_DIR_PATH>/lib/.libs/ --with-libiconv-type=static --with-gmp=<COMPILATION_DIR_PATH>/.libs/ --with-mpfr=<COMPILATION_DIR_PATH>/src/.libs/ CC=<CROSS_COMPILER_C> CXX=<CROSS_COMPILER_CPP> --host=<HOST_NAME>`
