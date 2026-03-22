#!/bin/sh
set -eu

# example script that builds vgmstream with most libs enabled using CMake
# Linux: installs dependencies with apt
# macOS: installs dependencies with brew, and if FB2K_SDK_PATH is set also builds the foobar2000 component package

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"

case "$(uname)" in
  Linux)
    sudo apt-get -y update
    sudo apt-get install -y gcc g++ make build-essential git cmake
    sudo apt-get install -y libmpg123-dev libvorbis-dev libspeex-dev
    sudo apt-get install -y libavformat-dev libavcodec-dev libavutil-dev libswresample-dev
    sudo apt-get install -y yasm libopus-dev
    sudo apt-get install -y libao-dev audacious-dev
    ;;
  Darwin)
    brew install cmake pkgconfig ffmpeg libao libvorbis mpg123 speex autoconf automake libtool yasm opus
    ;;
  *)
    echo "Unsupported platform: $(uname)" >&2
    exit 1
    ;;
esac

mkdir -p "$BUILD_DIR"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -DBUILD_AUDACIOUS:BOOL=OFF
cmake --build "$BUILD_DIR"

if [ "$(uname)" = "Darwin" ] && [ -n "${FB2K_SDK_PATH:-}" ]; then
  FB2K_MAC_BUILD_DIR="${FB2K_MAC_BUILD_DIR:-$BUILD_DIR/fb2k-macos}" \
  LIBVGMSTREAM_PATH="${LIBVGMSTREAM_PATH:-$ROOT_DIR/src/libvgmstream.a}" \
  FB2K_MAC_LINK_OPTIONAL_DEPS="${FB2K_MAC_LINK_OPTIONAL_DEPS:-0}" \
  VGMSTREAM_BUILD_DIR="${VGMSTREAM_BUILD_DIR:-$BUILD_DIR}" \
  "$ROOT_DIR/scripts/build_fb2k_macos.sh"
fi
