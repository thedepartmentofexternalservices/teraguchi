#!/usr/bin/env bash
# Shared client-only target policy. Mac Host policy is independent.
plank_macos_client_target() {
    export PLANK_MACOS_CLIENT_TARGET=${PLANK_MACOS_CLIENT_TARGET:-26.0}
    case "$PLANK_MACOS_CLIENT_TARGET" in
        26.0|27.0) ;;
        *) echo 'Client deployment target must be 26.0 or 27.0' >&2; return 2 ;;
    esac
    [[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || return 2
    if [[ -n ${MACOSX_DEPLOYMENT_TARGET:-} && $MACOSX_DEPLOYMENT_TARGET != "$PLANK_MACOS_CLIENT_TARGET" ]]; then
        echo 'Conflicting client deployment targets' >&2; return 2
    fi
    export MACOSX_DEPLOYMENT_TARGET=$PLANK_MACOS_CLIENT_TARGET
    export SDKROOT
    SDKROOT=$(xcrun --sdk macosx --show-sdk-path) || return
    PLANK_MACOS_CLIENT_SDK=$(xcrun --sdk macosx --show-sdk-version) || return
    [[ $PLANK_MACOS_CLIENT_SDK =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || return 2
    [[ ${PLANK_MACOS_CLIENT_SDK%%.*} -ge ${PLANK_MACOS_CLIENT_TARGET%%.*} ]] || {
        echo 'The selected Apple SDK is older than the client deployment target' >&2; return 2;
    }
    export PLANK_MACOS_CLIENT_SDK
}

# Each private dependency directory belongs to one target/SDK/patch combination.
# A build never silently reuses libraries prepared for another combination.
plank_macos_client_dependency_profile() {
    local mode=$1 source_root=$2 profile expected recipe_hash
    case "$mode" in bootstrap|build) ;; *) return 2 ;; esac
    profile="$PLANK_MAC_CLIENT_DEPS/.teraguchi-client-profile"
    recipe_hash=$(shasum -a 256 "$source_root/scripts/build/bootstrap-macos-client-deps.sh") || return
    expected=$(printf 'target=%s\nsdk=%s\nbootstrap_sha256=%s\n' \
        "$PLANK_MACOS_CLIENT_TARGET" "$PLANK_MACOS_CLIENT_SDK" "${recipe_hash%% *}")
    if [[ -f $profile ]]; then
        [[ $(cat "$profile") == "$expected" ]] || {
            echo 'Dependency profile mismatch: use a fresh target/SDK dependency directory' >&2; return 2;
        }
    elif [[ $mode == bootstrap && ! -d "$PLANK_MAC_CLIENT_DEPS/install" ]]; then
        mkdir -p "$PLANK_MAC_CLIENT_DEPS"
        printf '%s\n' "$expected" > "$profile"
    else
        echo 'Missing dependency profile: bootstrap a fresh dependency directory' >&2; return 2
    fi
}
