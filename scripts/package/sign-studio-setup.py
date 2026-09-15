#!/usr/bin/env python3
"""Sign a bounded studio setup document with an operator-provided Ed25519 key.

Run offline. Output and signing material must remain outside Git. This does not
create production keys, contact Tailscale, or sign/notarize the client app.
"""
import argparse
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

DOMAIN = b'Teraguchi studio setup v1\n'
FIELDS = {'version', 'revision', 'label', 'dns_suffix', 'issued_at', 'expires_at'}

def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate field')
        result[key] = value
    return result

def payload(path):
    with path.open("rb") as source:
        raw = source.read(4097)
    if len(raw) > 4096:
        raise ValueError('Profile too large')
    obj = json.loads(raw, object_pairs_hook=unique)
    if not isinstance(obj, dict) or set(obj) != FIELDS:
        raise ValueError('Unsupported profile fields')
    if type(obj['version']) is not int or obj['version'] != 1 or type(obj['revision']) is not int or not 1 <= obj['revision'] <= 2147483647:
        raise ValueError('Invalid version/revision')
    label, suffix = obj['label'], obj['dns_suffix']
    if not isinstance(label, str) or not label or len(label.encode('utf-16-le')) // 2 > 80 or label != label.strip() or re.search(r'[\x00-\x1f\x7f<>]', label):
        raise ValueError('Invalid studio label')
    if not isinstance(suffix, str) or not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.ts\.net', suffix):
        raise ValueError('Invalid exact Tailscale suffix')
    dates = []
    for key in ('issued_at', 'expires_at'):
        date = datetime.strptime(obj[key], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
        if date.strftime('%Y-%m-%dT%H:%M:%SZ') != obj[key]:
            raise ValueError('Invalid UTC date')
        dates.append(date.timestamp())
    if not 0 < dates[1] - dates[0] <= 90 * 86400 or not 0 < dates[0] <= datetime.now(timezone.utc).timestamp() < dates[1]:
        raise ValueError('Setup must be current and valid for at most 90 days')
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')

def outside_git(path):
    if subprocess.run(['git', '-C', str(path.parent), 'rev-parse', '--show-toplevel'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise ValueError('Keep studio configuration and signing material outside Git')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', required=True, type=Path)
    parser.add_argument('--private-key', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--openssl', required=True, type=Path, help='Pinned OpenSSL 3 executable')
    args = parser.parse_args()
    os.umask(0o077)
    for path in (args.profile, args.private_key, args.output, args.openssl):
        if not path.is_absolute():
            raise ValueError('All paths must be absolute')
    for path in (args.profile, args.private_key, args.output):
        outside_git(path.resolve())
    if args.output.exists() or args.output.is_symlink():
        raise ValueError('Refusing to overwrite output')
    if not args.output.parent.is_dir() or args.output.parent.stat().st_mode & 0o077 or not args.private_key.is_file() or args.private_key.stat().st_mode & 0o077:
        raise ValueError('Use an existing private output directory and owner-only signing key')
    content = payload(args.profile)
    with tempfile.TemporaryDirectory(prefix='studio-sign-', dir=args.output.parent) as temporary:
        temporary = Path(temporary)
        message, signature = temporary/'message', temporary/'signature'
        message.write_bytes(DOMAIN + content)
        public = subprocess.run([str(args.openssl), 'pkey', '-in', str(args.private_key), '-pubout', '-outform', 'DER'], stdout=subprocess.PIPE, check=True).stdout
        if len(public) != 44 or public[:12] != bytes.fromhex('302a300506032b6570032100'):
            raise ValueError('An Ed25519 key is required')
        # An encrypted key may prompt through OpenSSL; no passwords in arguments.
        result = subprocess.run([str(args.openssl), 'pkeyutl', '-sign', '-rawin', '-inkey', str(args.private_key), '-in', str(message), '-out', str(signature)], stdout=subprocess.DEVNULL)
        if result.returncode or not signature.exists() or signature.stat().st_size != 64:
            raise ValueError('Signing failed; an Ed25519 key is required')
        envelope = json.dumps({'payload': base64.b64encode(content).decode(), 'signature': base64.b64encode(signature.read_bytes()).decode()}, sort_keys=True, separators=(',', ':'))
        with args.output.open('x') as output:
            output.write(envelope + '\n')
    print('Studio setup signed. Distribute it with the client that pins this key.')

if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, TypeError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Studio setup failed: {error.__class__.__name__}; check inputs and private permissions.')
