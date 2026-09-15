#!/usr/bin/env bash
set -euo pipefail
role=${1:?product role required}
export CARGO_HOME="$PLANK_CARGO_ROOT" RUSTUP_HOME="$PLANK_RUSTUP_ROOT"
export PATH="$CARGO_HOME/bin:$PATH"
export CARGO_NET_OFFLINE=true
case $role in
  linux-host)
    export PLANK_HOST_FFMPEG_BUILD="$PLANK_SOURCE_ROOT/apps/host/linux/third-party/build-deps/build"
    export PLANK_HOST_FFMPEG_ROOT="$PLANK_DEP_ROOT/host-ffmpeg"
    export PLANK_BOOST_SOURCE_DIR="$PLANK_DEP_ROOT/boost-1.89.0"
    mkdir -p "$PLANK_SOURCE_ROOT/apps/host/linux/cmake-build-ffmpeg-x264rgb-install" "$PLANK_WORK_ROOT/tmp"
    ln -s "$PLANK_HOST_FFMPEG_ROOT" "$PLANK_SOURCE_ROOT/apps/host/linux/cmake-build-ffmpeg-x264rgb-install/ffmpeg"
    TMPDIR="$PLANK_WORK_ROOT/tmp" bash "$PLANK_SOURCE_ROOT/scripts/package/build-host-rpm.sh" "$PLANK_WORK_ROOT/host-build" "$PLANK_WORK_ROOT/host-package"
    ;;
  linux-client)
    bash "$PLANK_SOURCE_ROOT/scripts/build/build-client-package-binaries.sh" \
      "$PLANK_SOURCE_ROOT/apps/client" "$PLANK_DEP_ROOT/client-ffmpeg" "$PLANK_WORK_ROOT/client-build"
    bash "$PLANK_SOURCE_ROOT/scripts/package/build-client-deb.sh" \
      "$PLANK_WORK_ROOT/client-build/app/plank-client" "$PLANK_DEP_ROOT/client-ffmpeg" \
      "$PLANK_WORK_ROOT/client-package" "$PLANK_SOURCE_ROOT/apps/client"
    ;;
  macos-host)
    source "$PLANK_SOURCE_ROOT/scripts/package/package-version.sh"
    plank_load_package_version "$PLANK_SOURCE_ROOT"
    PLANK_MACOS_SOURCE_FIRST=1 bash "$PLANK_SOURCE_ROOT/scripts/build/build-macos-transport.sh" "$PLANK_SOURCE_ROOT" "$PLANK_WORK_ROOT/transport"
    if [[ ${PLANK_CI_SIGNED:-false} = true ]]; then
      bash "$PLANK_SOURCE_ROOT/scripts/package/build-macos-host-pkg.sh" "$PLANK_SOURCE_ROOT" "$PLANK_WORK_ROOT/host-package" "$PLANK_WORK_ROOT/transport/release/libplank_transport.a"
    else
      PLANK_MACOS_HOST_VERSION="$PLANK_PACKAGE_VERSION" bash "$PLANK_SOURCE_ROOT/scripts/build/build-macos-host.sh" \
        "$PLANK_SOURCE_ROOT" "$PLANK_WORK_ROOT/host-build" "$PLANK_WORK_ROOT/transport/release/libplank_transport.a"
    fi
    ;;
  macos-client)
    source "$PLANK_SOURCE_ROOT/scripts/build/macos-client-target.sh"
    plank_macos_client_target
    export PLANK_MAC_CLIENT_DEPS="$PLANK_DEP_ROOT/client-$PLANK_MACOS_CLIENT_TARGET-sdk$PLANK_MACOS_CLIENT_SDK"
    export PLANK_QT_ROOT="$PLANK_DEP_ROOT/qt/6.10.2/macos"
    if [[ ${PLANK_CI_SIGNED:-false} = true ]]; then
      bash "$PLANK_SOURCE_ROOT/scripts/package/build-macos-client-dmg.sh" "$PLANK_SOURCE_ROOT" "$PLANK_WORK_ROOT/client-package"
      client_build=${PLANK_MAC_CLIENT_BUILD:-"$PLANK_WORK_ROOT/client-package/build"}
    else
      bash "$PLANK_SOURCE_ROOT/scripts/build/build-macos-client.sh" "$PLANK_SOURCE_ROOT" "$PLANK_WORK_ROOT/client-build"
      client_build="$PLANK_WORK_ROOT/client-build"
    fi
    bash "$PLANK_SOURCE_ROOT/scripts/test/build-macos-decode-probe.sh" "$PLANK_WORK_ROOT/decode-probe"
    python3 "$PLANK_SOURCE_ROOT/scripts/test/check-macos-decode-probe.py" "$PLANK_WORK_ROOT/decode-probe/macos-videotoolbox-decode" "$PLANK_WORK_ROOT/decode-cases"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-quit-bridge.sh" "$PLANK_WORK_ROOT/quit-regression"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-strict-video.sh" "$PLANK_WORK_ROOT/strict-video"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-client-pen.sh" "$PLANK_WORK_ROOT/pen-input" \
      "$client_build/moonlight-common-c/libmoonlight-common-c.a"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-tablet-cursor.sh" "$PLANK_WORK_ROOT/tablet-cursor" --build-only
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-client-keyboard.sh" "$PLANK_WORK_ROOT/keyboard-input"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-studio-setup.sh" "$PLANK_WORK_ROOT/studio-setup"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-host-trust.sh" "$PLANK_WORK_ROOT/host-trust"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-client-release.sh" "$PLANK_WORK_ROOT/client-release"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-support-diagnostics.sh" "$PLANK_WORK_ROOT/support-diagnostics"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-input-permissions.sh" "$PLANK_WORK_ROOT/mac-input-permissions"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-presentation.sh" "$PLANK_WORK_ROOT/mac-presentation"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-macos-display-binding.sh" "$PLANK_WORK_ROOT/mac-display-binding"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-tailscale-workstations.sh" "$PLANK_WORK_ROOT/tailscale-workstations"
    bash "$PLANK_SOURCE_ROOT/scripts/test/check-workstation-ui.sh" "$PLANK_WORK_ROOT/workstation-ui"
    PLANK_CLIENT_EXECUTABLE="$client_build/app/plank-client.app/Contents/MacOS/plank-client" \
      bash "$PLANK_SOURCE_ROOT/scripts/test/check-workstation-client.sh" "$PLANK_WORK_ROOT/workstation-client"
    ;;
  *) exit 2 ;;
esac
test -z "$(git -C "$PLANK_SOURCE_ROOT" status --porcelain)"
echo 'hosted_build_gate=pass hardware_acceptance=not-performed'
