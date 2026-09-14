#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-strict-video.sh PRIVATE_OUTPUT_DIRECTORY}
: "${PLANK_MAC_CLIENT_DEPS:?Set the pinned FFmpeg dependency tree}"
mkdir -p "$output"
flags=(-std=c++17 -Wall -Wextra -Werror
    "-I$source_root/apps/client/moonlight-common-c/moonlight-common-c/src")
"${CXX:-c++}" "${flags[@]}" "$source_root/tests/video/strict-video-admission.cpp" -o "$output/admission-upstream"
"$output/admission-upstream" upstream
set +e
"$output/admission-upstream" strict
negative_status=$?
set -e
[[ $negative_status == 12 ]] || { echo 'Missing strict policy was not detected' >&2; exit 1; }
"${CXX:-c++}" "${flags[@]}" -DTERAGUCHI_STRICT_VIDEO \
    "$source_root/tests/video/strict-video-admission.cpp" -o "$output/admission-strict"
"$output/admission-strict" strict
"${CXX:-c++}" "${flags[@]}" "-I$PLANK_MAC_CLIENT_DEPS/install/include" \
    "$source_root/tests/video/strict-video-frame.cpp" \
    "-L$PLANK_MAC_CLIENT_DEPS/install/lib" "-Wl,-rpath,$PLANK_MAC_CLIENT_DEPS/install/lib" \
    -lavutil -o "$output/frame-contract"
"$output/frame-contract"
