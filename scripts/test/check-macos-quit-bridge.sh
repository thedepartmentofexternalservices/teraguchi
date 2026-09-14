#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
source "$source_root/scripts/build/macos-client-target.sh"
plank_macos_client_target
: "${PLANK_QT_ROOT:?set PLANK_QT_ROOT to the pinned Qt tree}"
: "${PLANK_MAC_CLIENT_DEPS:?set PLANK_MAC_CLIENT_DEPS to the prepared dependency tree}"
output=${1:?usage: check-macos-quit-bridge.sh PRIVATE_OUTPUT_DIRECTORY}
mkdir -p "$output"
compiler=$(xcrun --find clang++)
flags=(-std=c++17 -include arm_acle.h -isysroot "$SDKROOT"
    "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
    "-F$PLANK_QT_ROOT/lib" "-I$PLANK_QT_ROOT/lib/QtCore.framework/Headers"
    "-I$PLANK_MAC_CLIENT_DEPS/install/include" "-I$source_root/apps/client/app"
    "$source_root/tests/video/macos-quit-bridge.cpp"
    "-L$PLANK_MAC_CLIENT_DEPS/install/lib" -framework QtCore -lSDL3
    "-Wl,-rpath,$PLANK_QT_ROOT/lib" "-Wl,-rpath,$PLANK_MAC_CLIENT_DEPS/install/lib")
"$compiler" "${flags[@]}" -DTEST_WITHOUT_BRIDGE -o "$output/quit-original"
# Prove this test detects the missing handoff rather than only exercising a quit.
set +e
"$output/quit-original" streaming
original_status=$?
set -e
[[ $original_status == 12 ]] || { echo 'Original-loop regression was not reproduced' >&2; exit 1; }
"$compiler" "${flags[@]}" -o "$output/quit-fixed"
for scenario in idle streaming disconnect unrelated; do
    "$output/quit-fixed" "$scenario"
    printf 'macos_quit_%s=pass\n' "$scenario"
done
