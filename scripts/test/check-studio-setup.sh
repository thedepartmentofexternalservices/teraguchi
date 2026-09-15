#!/usr/bin/env bash
# Native parser/process tests. Uses synthetic child processes, never Tailscale/hosts.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-studio-setup.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_MAC_CLIENT_DEPS:?Set the retained Mac client dependency root}"
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
# The retained OpenSSL CLI still uses its packaging prefix for dylibs.
export DYLD_LIBRARY_PATH="$PLANK_MAC_CLIENT_DEPS/install/lib"
# Ephemeral test key and script-produced profile. Never a distribution key.
python3 - "$source_root" "$output" "$PLANK_MAC_CLIENT_DEPS/install/bin/openssl" <<'PYFIX'
from datetime import datetime, timedelta, timezone
from pathlib import Path
import json, os, subprocess, sys
root, output, openssl = sys.argv[1:]
out=Path(output)
key=out/'fixture-private.pem'
subprocess.run([openssl,'genpkey','-algorithm','ED25519','-out',str(key)],check=True)
key.chmod(0o600)
public=subprocess.check_output([openssl,'pkey','-in',str(key),'-pubout','-outform','DER'])
assert len(public)==44 and public[:12].hex()=='302a300506032b6570032100'
(out/'fixture-public.hex').write_text(public[-32:].hex())
now=datetime.now(timezone.utc).replace(microsecond=0)
iso=lambda d:d.strftime('%Y-%m-%dT%H:%M:%SZ')
profile={'version':2,'revision':1,'label':'Example Studio','dns_suffix':'studio-example.ts.net','issued_at':iso(now-timedelta(seconds=60)),'expires_at':iso(now+timedelta(hours=1))}
profile['workstations']=[{'node_id':'node-a','host_id':'host-a','certificate_sha256':['a'*64,'b'*64]}]
(out/'profile.json').write_text(json.dumps(profile))
signed=out/'fixture.teraguchi-studio'
if signed.exists(): signed.unlink()
subprocess.run([sys.executable,root+'/scripts/package/sign-studio-setup.py','--openssl',openssl,'--private-key',str(key),'--profile',str(out/'profile.json'),'--output',str(signed)],check=True)
# Signing must reject unsupported fields and an existing destination.
profile['auth_key']='not-allowed'
(out/'invalid-profile.json').write_text(json.dumps(profile))
for source,destination in [('invalid-profile.json','invalid.teraguchi-studio'),('profile.json','fixture.teraguchi-studio')]:
    result=subprocess.run([sys.executable,root+'/scripts/package/sign-studio-setup.py','--openssl',openssl,'--private-key',str(key),'--profile',str(out/source),'--output',str(out/destination)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    assert result.returncode!=0
PYFIX
export PLANK_STUDIO_CONFIG_PUBLIC_KEY=$(cat "$output/fixture-public.hex")
export STUDIO_SETUP_TEST_PUBLIC_KEY="$PLANK_STUDIO_CONFIG_PUBLIC_KEY"
export STUDIO_SETUP_TEST_BUILD_KEY="$PLANK_STUDIO_CONFIG_PUBLIC_KEY"
export STUDIO_SETUP_TEST_FILE="$output/fixture.teraguchi-studio"
mkdir -p "$output/build"
(
    cd "$output/build"
    "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/tailscale/studio-setup.pro"
    make -j4
) > "$output/build.log" 2>&1
"$output/build/studio-setup-tests" -o "$output/tests.txt,txt"

# Check key-input validation independently of compilation.
mkdir -p "$output/invalid-key-build"
if (cd "$output/invalid-key-build" && PLANK_STUDIO_CONFIG_PUBLIC_KEY=invalid "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/tailscale/studio-setup.pro") > "$output/invalid-key.log" 2>&1; then
    echo 'Malformed build verification key accepted' >&2; exit 1
fi

# Removing a key must update the compiled result in the SAME retained build.
(
    cd "$output/build"
    PLANK_STUDIO_CONFIG_PUBLIC_KEY= "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/tailscale/studio-setup.pro"
    make -j4
) > "$output/key-removal-build.log" 2>&1
STUDIO_SETUP_TEST_BUILD_KEY= "$output/build/studio-setup-tests" signingToolInteroperabilityAndPinnedKey -o "$output/key-removal-tests.txt,txt"
