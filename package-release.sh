#!/usr/bin/env bash

set -e

shopt -s extglob

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 version destdir [--native] [--no-package] [--dev-build] [--debug]"
  exit 1
fi

install_llvm_mingw() {

    # LLVM MinGW Setup
    LLVM_MINGW_URL="https://github.com/v3kt0r-87/Clang-Stable/releases/download/llvm-migw-19.1.7/llvm-mingw.zip"
    LLVM_MINGW_PATH="$(pwd)/llvm-mingw"


    echo "Checking for LLVM MinGW..."

    if [ ! -d "$LLVM_MINGW_PATH" ]; then

        echo "LLVM MinGW not found! Downloading..."

        wget -O llvm-mingw.zip "$LLVM_MINGW_URL"

        unzip llvm-mingw.zip -d "$LLVM_MINGW_PATH"
        rm llvm-mingw.zip

        echo "LLVM MinGW installed successfully!"

    else
        echo "LLVM MinGW is already installed."
    fi

    export PATH="$(pwd)/llvm-mingw/bin:$PATH"
}

install_llvm_mingw

VKD3D_VERSION="$1"
VKD3D_SRC_DIR=$(dirname "$(readlink -f "$0")")
VKD3D_BUILD_DIR=$(realpath "$2")"/vkd3d-proton-$VKD3D_VERSION"
VKD3D_ARCHIVE_PATH=$(realpath "$2")"/vkd3d-proton-$VKD3D_VERSION.tar.zst"

if [ -e "$VKD3D_BUILD_DIR" ]; then
  echo "Build directory $VKD3D_BUILD_DIR already exists"
  exit 1
fi

shift 2

opt_nopackage=0
opt_devbuild=0
opt_native=0
opt_buildtype="release"
opt_strip=--strip

while [ $# -gt 0 ]; do
  case "$1" in
  "--native")
    opt_native=1
    ;;
  "--no-package")
    opt_nopackage=1
    ;;
  "--dev-build")
    opt_strip=
    opt_nopackage=1
    opt_devbuild=1
    ;;
 "--debug")
    opt_buildtype="debug"
    ;;
  *)
    echo "Unrecognized option: $1" >&2
    exit 1
  esac
  shift
done

function build_arch {
  local arch="$1"
  shift

  cd "$VKD3D_SRC_DIR"

  meson setup "$@"                     \
        --native-file "native.txt"     \
        --buildtype "${opt_buildtype}" \
        --prefix "$VKD3D_BUILD_DIR"    \
        $opt_strip                     \
        --bindir "x${arch}"            \
        --libdir "x${arch}"            \
        -Db_lto=true                   \
        "$VKD3D_BUILD_DIR/build.${arch}"

  cd "$VKD3D_BUILD_DIR/build.${arch}"
  ninja install

  if [ $opt_devbuild -eq 0 ]; then
    if [ $opt_native -eq 0 ]; then
        # get rid of some useless .a files
        rm "$VKD3D_BUILD_DIR/x${arch}/"*.!(dll)
    fi
    rm -R "$VKD3D_BUILD_DIR/build.${arch}"
  fi
}

function build_script {
  cp "$VKD3D_SRC_DIR/setup_vkd3d_proton.sh" "$VKD3D_BUILD_DIR/setup_vkd3d_proton.sh"
  chmod +x "$VKD3D_BUILD_DIR/setup_vkd3d_proton.sh"
}

function package {
  cd "$VKD3D_BUILD_DIR/.."
  tar -caf "$VKD3D_ARCHIVE_PATH" "vkd3d-proton-$VKD3D_VERSION"
  rm -R "vkd3d-proton-$VKD3D_VERSION"
}

if [ $opt_native -eq 0 ]; then
  build_arch 64 --cross-file build-win64.txt
  build_arch 86 --cross-file build-win32.txt
  build_script
else
  build_arch 64
  CC="gcc -m32" CXX="g++ -m32" PKG_CONFIG_PATH="/usr/lib32/pkgconfig:/usr/lib/i386-linux-gnu/pkgconfig:/usr/lib/pkgconfig" build_arch 86
fi

if [ $opt_nopackage -eq 0 ]; then
  package
fi
