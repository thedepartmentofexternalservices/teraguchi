#!/usr/bin/env python3
"""Exact-input prepared-library cache. No app objects, accounts or signing state."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess

INPUTS = (
    'scripts/ci/cache-macos-client.py',
    'scripts/ci/bootstrap.sh',
    'scripts/build/bootstrap-macos-client-deps.sh',
    'scripts/build/build-paths.sh',
    'scripts/build/macos-client-target.sh',
    'scripts/build/relocate-openssl-pc.py',
    'scripts/build/sanitize-ffmpeg-build-info.py',
)
PATCH = 'apps/client/app/deploy/linux/ffmpeg-patches/0001-hevc-enable-hwaccel-for-identity-gbr.patch'
KEY_PREFIX = 'plank-macos-client-deps-v1-'


def fingerprint(root, dependency_root, toolchain):
    paths = set(INPUTS) | {PATCH}
    paths.update(str(p.relative_to(root)) for p in (root / Path(PATCH).parent).glob('*.patch'))
    hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sorted(paths)}
    # Prepared .pc/CMake/dylib metadata has absolute build prefixes. Never reuse
    # it under a different path, SDK, compiler or OS image. App/version changes
    # deliberately do not invalidate these independent libraries.
    data = {'schema': 1, 'inputs': hashes, 'source_root': str(root),
            'dependency_root': str(dependency_root), 'toolchain': toolchain}
    return KEY_PREFIX + hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def resolve_profile(root):
    # Use the same target/SDK policy as bootstrap and build, including conflict
    # checks, instead of maintaining a second default or consulting a stale env.
    values = subprocess.check_output([
        'bash', '-c',
        'source "$1"; plank_macos_client_target || exit; '
        'printf "%s\\n%s\\n" "$PLANK_MACOS_CLIENT_TARGET" "$PLANK_MACOS_CLIENT_SDK"',
        'cache-target', str(root / 'scripts/build/macos-client-target.sh'),
    ], text=True).splitlines()
    if len(values) != 2:
        raise ValueError('Invalid resolved Client dependency profile')
    return {'target': values[0], 'sdk': values[1]}


def client_directory(deps, profile):
    target, sdk = profile['target'], profile['sdk']
    if target not in ('26.0', '27.0') or not re.fullmatch(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?', sdk):
        raise ValueError('Invalid Client dependency profile')
    if int(sdk.split('.')[0]) < int(target.split('.')[0]):
        raise ValueError('SDK is older than the Client deployment target')
    return deps / f'client-{target}-sdk{sdk}'


def cache_paths(deps, profile):
    client = client_directory(deps, profile)
    return [client / 'install', client / 'src', client / 'downloads',
            client / '.teraguchi-client-profile', deps / 'qt',
            client / 'cache-receipt.json']


def key_valid(key):
    return re.fullmatch(re.escape(KEY_PREFIX) + '[0-9a-f]{64}', key) is not None


def verify_receipt(deps, key, profile):
    if not key_valid(key):
        raise ValueError('Invalid dependency cache key')
    receipt = json.loads(cache_paths(deps, profile)[-1].read_text())
    if receipt != {'schema': 1, 'key': key}:
        raise ValueError('Restored dependency cache does not match exact inputs')


def check_prepared(root, deps, profile):
    client = client_directory(deps, profile)
    for path in (client / 'install/lib/libavcodec.dylib', deps / 'qt/6.10.2/macos/bin/qmake'):
        if not path.is_file():
            raise ValueError('Incomplete prepared dependency cache')
    recipe = hashlib.sha256((root / 'scripts/build/bootstrap-macos-client-deps.sh').read_bytes()).hexdigest()
    expected = f"target={profile['target']}\nsdk={profile['sdk']}\nbootstrap_sha256={recipe}\n"
    if (client / '.teraguchi-client-profile').read_text() != expected:
        raise ValueError('Prepared dependencies have a different target, SDK or recipe')
    # Check the required source patch independently of a cache-hit claim.
    with (root / PATCH).open('rb') as patch:
        subprocess.run(['patch', '--batch', '--reverse', '--dry-run', '-p1',
                        '-d', str(client / 'src/ffmpeg-9.0.1')], stdin=patch, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare', 'verify', 'seal'))
    parser.add_argument('--key')
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('Cache is qualified only for the Apple Silicon Mac Client builder')
    root = Path(os.environ['PLANK_SOURCE_ROOT']).resolve()
    deps = Path(os.environ['PLANK_DEP_ROOT']).resolve()
    profile = resolve_profile(root)
    if args.operation == 'prepare':
        # Resolve patch bytes, not the whole Client commit: a UI-only commit
        # must not force FFmpeg/OpenSSL/SDL/Qt to be rebuilt.
        subprocess.run(['git', '-C', str(root), 'submodule', 'update', '--init', 'apps/client'], check=True)
        commands = (['sw_vers', '-productVersion'], ['sw_vers', '-buildVersion'],
                    ['xcodebuild', '-version'], ['xcrun', '--sdk', 'macosx', '--show-sdk-version'],
                    ['xcrun', '--sdk', 'macosx', '--show-sdk-build-version'],
                    ['xcrun', 'clang', '--version'], ['cmake', '--version'],
                    ['ninja', '--version'], ['python3', '--version'])
        toolchain = {'client_profile': profile, 'architecture': platform.machine(), 'runner_image': os.environ.get('ImageVersion', ''),
                     'tools': [subprocess.check_output(c, text=True).strip() for c in commands]}
        key = fingerprint(root, deps, toolchain)
        paths = '\n'.join(str(p) for p in cache_paths(deps, profile))
        if any(c in str(root) + str(deps) for c in ('\n', '\r')):
            raise ValueError('Invalid builder path')
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'key={key}\npaths<<PLANK_CACHE_PATHS\n{paths}\nPLANK_CACHE_PATHS\n')
        print('macos_client_dependency_cache_key=' + key)
        return
    if not key_valid(args.key or ''):
        raise ValueError('Exact dependency key required')
    if args.operation == 'verify':
        verify_receipt(deps, args.key, profile)
    check_prepared(root, deps, profile)
    if args.operation == 'seal':
        cache_paths(deps, profile)[-1].write_text(json.dumps({'schema': 1, 'key': args.key}, sort_keys=True) + '\n')
    print('macos_client_dependency_cache_' + args.operation + '=pass')


if __name__ == '__main__':
    main()
