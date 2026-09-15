#!/usr/bin/env bash
# Offline crop/layout tests. --gpu adds textures; --native also uses hidden windows.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-macos-presentation.sh ABSOLUTE_PRIVATE_OUTPUT [--gpu|--native]}
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
: "${PLANK_MAC_CLIENT_DEPS:?Set the retained Mac dependency root}"
[[ "$output" == /* && $(uname -s) == Darwin ]] || exit 2
[[ $# == 1 || ( $# == 2 && ( $2 == --gpu || $2 == --native ) ) ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
export PKG_CONFIG_PATH="$PLANK_MAC_CLIENT_DEPS/install/lib/pkgconfig"
export PATH="$PLANK_MAC_CLIENT_DEPS/install/bin:$PATH"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1 PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
for suite in metal presentation; do
    mkdir -p "$output/$suite"
    if [[ $suite == metal ]]; then
        project="$source_root/tests/video/macos-presentation.pro"
        target=mac-presentation-tests
    else
        project="$source_root/apps/client/tests/plankpresentation/plankpresentation.pro"
        target=plankpresentation
    fi
    (
        cd "$output/$suite"
        "$PLANK_QT_ROOT/bin/qmake" "$project" CONFIG+=console CONFIG-=app_bundle \
            QMAKE_MACOSX_DEPLOYMENT_TARGET=26.0 'QMAKE_CXXFLAGS+=-include arm_acle.h'
        make -j4
        "./$target" -o tests.txt,txt
    ) > "$output/$suite-build.log" 2>&1
done
if [[ ${2:-} == --gpu || ${2:-} == --native ]]; then
    compiler=$(xcrun --find clang++)
    "$compiler" -std=c++17 -fobjc-arc -include arm_acle.h \
        -isysroot "$(xcrun --sdk macosx --show-sdk-path)" -mmacosx-version-min=26.0 \
        "-F$PLANK_QT_ROOT/lib" "-I$PLANK_QT_ROOT/lib/QtCore.framework/Headers" \
        "-I$PLANK_MAC_CLIENT_DEPS/install/include" "-I$source_root/apps/client/app" \
        "$source_root/tests/video/macos-metal-outputs.mm" \
        "$source_root/apps/client/app/streaming/plankpresentation.cpp" \
        -framework QtCore -framework Foundation -framework Metal \
        "-Wl,-rpath,$PLANK_QT_ROOT/lib" -o "$output/metal-outputs" \
        > "$output/gpu-build.log" 2>&1
    set +e
    "$output/metal-outputs" "$source_root/apps/client/app/shaders/vt_renderer.metal" --uncropped > "$output/gpu-negative-control.txt" 2>&1
    control_status=$?
    set -e
    [[ $control_status == 7 ]] || { echo 'Uncropped regression control was not detected' >&2; exit 1; }
    "$output/metal-outputs" "$source_root/apps/client/app/shaders/vt_renderer.metal" > "$output/gpu-tests.txt" 2>&1
fi
if [[ ${2:-} == --native ]]; then
    mkdir -p "$output/lifecycle"
    (
        cd "$output/lifecycle"
        "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/video/macos-metal-lifecycle.pro"
        make -j4
    ) > "$output/lifecycle-build.log" 2>&1
    python3 - "$output" "$source_root" <<'PY'
import pathlib, subprocess, sys
output, source = map(pathlib.Path, sys.argv[1:])
with (output / 'lifecycle-tests.txt').open('w') as log:
    subprocess.run([str(output / 'lifecycle/mac-metal-lifecycle'),
                    str(source / 'apps/client/app/shaders/vt_renderer.metal')],
                   stdout=log, stderr=subprocess.STDOUT, check=True, timeout=45)
PY
fi
printf 'Mac presentation checks passed; physical displays not tested.\n'
