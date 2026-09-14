#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-macos-client-pen.sh PRIVATE_OUTPUT_DIRECTORY [COMMON_C_ARCHIVE]}
: "${PLANK_MAC_CLIENT_DEPS:?Set the pinned SDL dependency directory}"
mkdir -p "$output"
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror \
    "-I$PLANK_MAC_CLIENT_DEPS/install/include" \
    "-I$source_root/apps/client/moonlight-common-c/moonlight-common-c/src" \
    "$source_root/apps/client/app/streaming/input/macpen.cpp" \
    "$source_root/tests/input/macos-client-pen.cpp" -o "$output/macos-client-pen"
"$output/macos-client-pen"
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror \
    "-I$PLANK_MAC_CLIENT_DEPS/install/include" \
    "-I$source_root/apps/client/moonlight-common-c/moonlight-common-c/src" \
    "$source_root/apps/client/app/streaming/input/macpen.cpp" \
    "$source_root/tests/input/macos-pen-monitor.cpp" \
    "-L$PLANK_MAC_CLIENT_DEPS/install/lib" "-Wl,-rpath,$PLANK_MAC_CLIENT_DEPS/install/lib" \
    -lSDL3 -o "$output/macos-pen-monitor"
"$output/macos-pen-monitor" --help
if [[ $# == 2 ]]; then
    "${CC:-cc}" -std=c11 -Wall -Wextra -Werror \
        "-I$source_root/apps/client/moonlight-common-c/moonlight-common-c/src" \
        "-I$source_root/protocol/plank-transport/include" \
        "-I$PLANK_MAC_CLIENT_DEPS/install/include" \
        "$source_root/tests/session/native-input-wire.c" "$2" \
        "-L$PLANK_MAC_CLIENT_DEPS/install/lib" -lcrypto -o "$output/native-input-wire"
    "$output/native-input-wire"
fi
