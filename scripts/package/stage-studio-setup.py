#!/usr/bin/env python3
"""Verify and stage a signed studio setup in a new, unsigned Mac package tree."""
import argparse
import base64
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

spec = importlib.util.spec_from_file_location('studio_signer', Path(__file__).with_name('sign-studio-setup.py'))
signer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signer)


def verify_setup(setup, key_header, openssl):
    if setup.is_symlink() or not setup.is_file() or setup.stat().st_size > 8192:
        raise ValueError('Invalid setup file')
    raw = setup.read_bytes()
    envelope = json.loads(raw, object_pairs_hook=signer.unique)
    if not isinstance(envelope, dict) or set(envelope) != {'payload', 'signature'}:
        raise ValueError('Invalid envelope')
    if json.dumps(envelope, sort_keys=True, separators=(',', ':')).encode() != raw.strip():
        raise ValueError('Noncanonical envelope')
    content, signature = (base64.b64decode(envelope[k], validate=True) for k in ('payload', 'signature'))
    if any(base64.b64encode(value).decode() != envelope[k] for k, value in (('payload', content), ('signature', signature))):
        raise ValueError('Noncanonical base64')
    key = re.search(r'^#define TERAGUCHI_STUDIO_KEY_HEX "([0-9a-f]{64})"$', key_header.read_text(), re.M)
    if not key or len(signature) != 64:
        raise ValueError('Missing compiled verification key or signature')
    with tempfile.TemporaryDirectory(prefix='verify-studio-') as directory:
        directory = Path(directory)
        profile, public, message, signed = (directory/n for n in ('profile', 'public.der', 'message', 'signature'))
        profile.write_bytes(content)
        if signer.payload(profile) != content or json.loads(content)['version'] != 2:
            raise ValueError('Bundled setup requires canonical version 2')
        public.write_bytes(bytes.fromhex('302a300506032b6570032100' + key.group(1)))
        message.write_bytes(signer.DOMAIN + content)
        signed.write_bytes(signature)
        result = subprocess.run([str(openssl), 'pkeyutl', '-verify', '-rawin', '-pubin', '-keyform', 'DER',
            '-inkey', str(public), '-in', str(message), '-sigfile', str(signed)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        if result.returncode:
            raise ValueError('Signature does not match this build')
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--setup', default='')
    parser.add_argument('--key-header', required=True, type=Path)
    parser.add_argument('--openssl', required=True, type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    if not args.app.is_absolute() or args.app.is_symlink():
        raise ValueError('Use an absolute new package tree')
    signer.outside_git(args.app)
    destination = args.app/'Contents/Resources/studio-setup.teraguchi-studio'
    plist = args.app/'Contents/Info.plist'
    info = plistlib.loads(plist.read_bytes())
    if args.setup:
        setup = Path(args.setup)
        if not all(p.is_absolute() for p in (setup, args.key_header, args.openssl)):
            raise ValueError('Use absolute input paths')
        signer.outside_git(setup.resolve())
        raw = verify_setup(setup, args.key_header, args.openssl)
        with destination.open('xb') as output:
            output.write(raw)
        destination.chmod(0o644)
        info['TeraguchiWorkstationPicker'] = True
    else:
        # Only the new staging tree is mutable; prevent a retained build's old
        # setup from accidentally entering an unconfigured distribution.
        destination.unlink(missing_ok=True)
        info.pop('TeraguchiWorkstationPicker', None)
    plist.write_bytes(plistlib.dumps(info))
    print('bundled_studio_setup=' + ('verified' if args.setup else 'absent'))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, TypeError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Studio packaging failed: {error.__class__.__name__}; check private inputs.')
