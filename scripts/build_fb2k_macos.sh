#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${FB2K_SDK_PATH:-}" ]]; then
    echo "FB2K_SDK_PATH is required" >&2
    exit 1
fi

if [[ ! -d "$FB2K_SDK_PATH/foobar2000/foo_sample" ]]; then
    echo "FB2K_SDK_PATH does not look like an extracted foobar2000 SDK: $FB2K_SDK_PATH" >&2
    exit 1
fi

BUILD_ROOT="${FB2K_MAC_BUILD_DIR:-$ROOT_DIR/build/fb2k-macos}"
DERIVED_DATA_DIR="${FB2K_MAC_DERIVED_DATA_DIR:-$BUILD_ROOT/DerivedData}"
OBJECT_DIR="$BUILD_ROOT/objects"
PRODUCTS_DIR="$DERIVED_DATA_DIR/Build/Products/Release"
COMPONENT_DIR="${FB2K_MAC_OUTPUT_DIR:-$BUILD_ROOT/foo_input_vgmstream.component}"
ZIP_PATH="${FB2K_MAC_ZIP_PATH:-$BUILD_ROOT/foo_input_vgmstream.component.zip}"
LIBVGMSTREAM_PATH="${LIBVGMSTREAM_PATH:-$ROOT_DIR/src/libvgmstream.a}"
VGMSTREAM_BUILD_DIR="${VGMSTREAM_BUILD_DIR:-}"
FB2K_MAC_LINK_OPTIONAL_DEPS="${FB2K_MAC_LINK_OPTIONAL_DEPS:-0}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
ARCH="${ARCH:-$(uname -m)}"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

if [[ ! -f "$LIBVGMSTREAM_PATH" ]]; then
    make -C "$ROOT_DIR/src" libvgmstream.a
fi

if [[ ! -f "$LIBVGMSTREAM_PATH" ]]; then
    echo "libvgmstream archive not found: $LIBVGMSTREAM_PATH" >&2
    exit 1
fi

mkdir -p "$BUILD_ROOT" "$OBJECT_DIR"

xcodebuild \
    -workspace "$FB2K_SDK_PATH/foobar2000/foo_sample/foo_sample.xcworkspace" \
    -scheme foo_sample \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build

COMMON_CXXFLAGS=(
    -DNDEBUG
    -std=gnu++20
    -arch "$ARCH"
    -mmacosx-version-min="$MACOSX_DEPLOYMENT_TARGET"
    -isysroot "$SDKROOT"
    -I "$FB2K_SDK_PATH"
    -I "$FB2K_SDK_PATH/foobar2000"
    -I "$FB2K_SDK_PATH/foobar2000/SDK"
    -I "$FB2K_SDK_PATH/foobar2000/helpers"
    -I "$FB2K_SDK_PATH/foobar2000/shared"
    -I "$FB2K_SDK_PATH/pfc"
    -I "$ROOT_DIR"
    -I "$ROOT_DIR/src"
    -I "$ROOT_DIR/ext_includes"
)

xcrun clang++ "${COMMON_CXXFLAGS[@]}" -c "$ROOT_DIR/fb2k/foo_vgmstream.cpp" -o "$OBJECT_DIR/foo_vgmstream.o"
xcrun clang++ "${COMMON_CXXFLAGS[@]}" -c "$ROOT_DIR/fb2k/foo_streamfile.cpp" -o "$OBJECT_DIR/foo_streamfile.o"
xcrun clang++ "${COMMON_CXXFLAGS[@]}" -c "$ROOT_DIR/fb2k/foo_prefs.cpp" -o "$OBJECT_DIR/foo_prefs.o"
xcrun clang++ "${COMMON_CXXFLAGS[@]}" -fobjc-arc -c "$ROOT_DIR/fb2k/foo_prefs_mac.mm" -o "$OBJECT_DIR/foo_prefs_mac.o"

EXTRA_LINK_ARGS=()

append_pkg_config() {
    if ! command -v pkg-config >/dev/null 2>&1; then
        return
    fi
    if ! pkg-config --exists "$@"; then
        return
    fi
    local -a args
    read -r -a args <<< "$(pkg-config --libs "$@")"
    EXTRA_LINK_ARGS+=("${args[@]}")
}

append_first_pkg_config() {
    if ! command -v pkg-config >/dev/null 2>&1; then
        return
    fi
    local spec
    for spec in "$@"; do
        if pkg-config --exists "$spec"; then
            local -a args
            read -r -a args <<< "$(pkg-config --libs "$spec")"
            EXTRA_LINK_ARGS+=("${args[@]}")
            return
        fi
    done
}

append_if_exists() {
    local path
    for path in "$@"; do
        if [[ -f "$path" ]]; then
            EXTRA_LINK_ARGS+=("$path")
        fi
    done
}

if [[ "$FB2K_MAC_LINK_OPTIONAL_DEPS" = "1" ]]; then
    if [[ -n "$VGMSTREAM_BUILD_DIR" ]]; then
        append_if_exists \
            "$VGMSTREAM_BUILD_DIR/dependencies/mpg123/src/libmpg123/.libs/libmpg123.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/ogg/libogg.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/vorbis/lib/libvorbisfile.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/vorbis/lib/libvorbis.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/ffmpeg/bin/usr/local/lib/libavformat.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/ffmpeg/bin/usr/local/lib/libavcodec.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/ffmpeg/bin/usr/local/lib/libavutil.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/ffmpeg/bin/usr/local/lib/libswresample.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/libg719_decode/libg719_decode.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/LibAtrac9/bin/libatrac9.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/celt-0061/libcelt/.libs/libcelt.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/celt-0110/libcelt/.libs/libcelt0.a" \
            "$VGMSTREAM_BUILD_DIR/dependencies/speex/libspeex/.libs/libspeex.a"
    fi

    append_first_pkg_config libmpg123 mpg123
    append_pkg_config vorbisfile vorbis ogg
    append_pkg_config libavformat libavcodec libavutil libswresample
    append_first_pkg_config opus libopus
    append_first_pkg_config speex
fi

VERSION="$(
    awk -F '"' '/#define VGMSTREAM_VERSION "/ { print $2; exit }' "$ROOT_DIR/version.h"
)"
if [[ -z "$VERSION" ]]; then
    VERSION="unknown"
fi

LINK_ARGS=(
    -bundle
    -arch "$ARCH"
    -mmacosx-version-min="$MACOSX_DEPLOYMENT_TARGET"
    -isysroot "$SDKROOT"
    "$OBJECT_DIR/foo_vgmstream.o"
    "$OBJECT_DIR/foo_streamfile.o"
    "$OBJECT_DIR/foo_prefs.o"
    "$OBJECT_DIR/foo_prefs_mac.o"
    "$LIBVGMSTREAM_PATH"
    "$PRODUCTS_DIR/libfoobar2000_component_client.a"
    "$PRODUCTS_DIR/libshared.a"
    "$PRODUCTS_DIR/libfoobar2000_SDK.a"
    "$PRODUCTS_DIR/libfoobar2000_SDK_helpers.a"
    "$PRODUCTS_DIR/libpfc-Mac.a"
)

if (( ${#EXTRA_LINK_ARGS[@]} > 0 )); then
    LINK_ARGS+=("${EXTRA_LINK_ARGS[@]}")
fi

LINK_ARGS+=(
    -framework Cocoa
    -lm
    -lpthread
    -o "$BUILD_ROOT/foo_input_vgmstream"
)

xcrun clang++ "${LINK_ARGS[@]}"

rm -rf "$COMPONENT_DIR" "$ZIP_PATH"
mkdir -p "$COMPONENT_DIR/Contents/MacOS" "$COMPONENT_DIR/Contents/Resources"
cp "$BUILD_ROOT/foo_input_vgmstream" "$COMPONENT_DIR/Contents/MacOS/foo_input_vgmstream"

cat > "$COMPONENT_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>foo_input_vgmstream</string>
    <key>CFBundleIdentifier</key>
    <string>com.foobar2000.foo-input-vgmstream</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>foo_input_vgmstream</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MACOSX_DEPLOYMENT_TARGET}</string>
</dict>
</plist>
EOF

codesign --force --sign - --timestamp=none "$COMPONENT_DIR"
codesign --verify --deep --strict "$COMPONENT_DIR"

ditto -c -k --sequesterRsrc --keepParent "$COMPONENT_DIR" "$ZIP_PATH"

echo "Bundle: $COMPONENT_DIR"
echo "ZIP: $ZIP_PATH"
