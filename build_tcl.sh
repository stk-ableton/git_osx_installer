#!/bin/bash -x

set -e -o pipefail

export MAKEFLAGS=

TCL_VERSION=8.6.12
TCL_MAJOR_VERSION=8.6

TCL_SRC=tcl$TCL_VERSION-src.tar.gz
TK_SRC=tk$TCL_VERSION-src.tar.gz
TCL_DIR=build/tcl$TCL_VERSION
TK_DIR=build/tk$TCL_VERSION
TCL_DOWNLOAD_LOCATION=https://downloads.sourceforge.net/project/tcl/Tcl/$TCL_VERSION

GIT_PREFIX=/usr/local/git

OSX_VERSION=10.9
TARGET_FLAGS="-arch x86_64 -arch arm64 -mmacosx-version-min=$OSX_VERSION -DMACOSX_DEPLOYMENT_TARGET=$OSX_VERSION"

TCL_CONFIGURE_ARGS="--prefix=$GIT_PREFIX/tcl-tk --enable-threads --enable-64bit --disable-shared"
TK_CONFIGURE_ARGS="$TCL_CONFIGURE_ARGS --with-tcl=$GIT_PREFIX/tcl-tk/lib --enable-aqua=yes --without-x --without-ssl"

sudo rm -rf $GIT_PREFIX/tcl-tk

mkdir -p build

# Download
test -f build/$TCL_SRC || \
    ( curl -L -o build/$TCL_SRC.working "$TCL_DOWNLOAD_LOCATION/$TCL_SRC" \
	  && mv build/$TCL_SRC.working build/$TCL_SRC )

test -f build/$TK_SRC || \
    ( curl -L -o build/$TK_SRC.working "$TCL_DOWNLOAD_LOCATION/$TK_SRC" \
	  && mv build/$TK_SRC.working build/$TK_SRC )

# Extract
test -d $TCL_DIR || tar xzf build/$TCL_SRC -C build
test -d $TK_DIR || tar xzf build/$TK_SRC -C build

# Configure, build, and install
test -f $TCL_DIR/unix/Makefile || \
    ( cd $TCL_DIR/unix && CFLAGS="$TARGET_FLAGS" LDFLAGS="$TARGET_FLAGS" ./configure $TCL_CONFIGURE_ARGS )
( cd $TCL_DIR/unix && make -j9 && sudo make install)

test -f $TK_DIR/unix/Makefile || \
    ( cd $TK_DIR/unix && CFLAGS="$TARGET_FLAGS" LDFLAGS="$TARGET_FLAGS" ./configure $TK_CONFIGURE_ARGS )
( cd $TK_DIR/unix && make -j9 && sudo make install)
