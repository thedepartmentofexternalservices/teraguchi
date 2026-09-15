#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-macos-client-keyboard.sh PRIVATE_OUTPUT_DIRECTORY}
: "${PLANK_MAC_CLIENT_DEPS:?Set the pinned SDL dependency directory}"
mkdir -p "$output"
flags=(-std=c++17 -Wall -Wextra -Werror
    "-I$source_root/apps/client/app"
    "-I$PLANK_MAC_CLIENT_DEPS/install/include"
    "-I$source_root/apps/client/moonlight-common-c/moonlight-common-c/src")
"${CXX:-c++}" "${flags[@]}" \
    "$source_root/apps/client/app/streaming/input/mackeyboard.cpp" \
    "$source_root/apps/client/app/streaming/input/macpen.cpp" \
    "$source_root/tests/input/macos-client-keyboard.cpp" -o "$output/macos-client-keyboard"
"$output/macos-client-keyboard"
"${CXX:-c++}" "${flags[@]}" \
    "$source_root/tests/input/macos-system-key-bridge.mm" \
    "-L$PLANK_MAC_CLIENT_DEPS/install/lib" "-Wl,-rpath,$PLANK_MAC_CLIENT_DEPS/install/lib" \
    -lSDL3 -framework AppKit -framework ApplicationServices -framework Carbon \
    -o "$output/macos-system-key-bridge"
"$output/macos-system-key-bridge"
