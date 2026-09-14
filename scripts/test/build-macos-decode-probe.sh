#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
: "${PLANK_MAC_CLIENT_DEPS:?Set the pinned, hardware-patched FFmpeg dependency tree}"
output=${1:?usage: build-macos-decode-probe.sh PRIVATE_OUTPUT_DIRECTORY}
mkdir -p "$output"
sdk=$(xcrun --sdk macosx --show-sdk-path)
# Standalone probe only; the product build keeps its own deployment policy.
target=${MACOSX_DEPLOYMENT_TARGET:-27.0}
"$(xcrun --find clang++)" -std=c++17 -Wall -Wextra -Werror -isysroot "$sdk" \
    "-mmacosx-version-min=$target" \
    "-I$PLANK_MAC_CLIENT_DEPS/install/include" \
    "$source_root/tests/video/macos-videotoolbox-decode.mm" \
    "-L$PLANK_MAC_CLIENT_DEPS/install/lib" \
    "-Wl,-rpath,$PLANK_MAC_CLIENT_DEPS/install/lib" \
    -lavformat -lavcodec -lavutil -framework VideoToolbox -framework CoreVideo \
    -framework CoreFoundation -o "$output/macos-videotoolbox-decode"
