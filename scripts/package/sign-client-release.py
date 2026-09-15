#!/usr/bin/env python3
"""Sign offline release metadata for one collected Mac client DMG.

This does not sign/notarize the application, create keys, or publish a release.
The supplied Ed25519 key must be usable noninteractively by pinned OpenSSL 3.
"""
import argparse
import os
from pathlib import Path
import subprocess
import time

import release_manifest as release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('profile', 'collection', 'package', 'private-key', 'openssl', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        release.require(all(path.is_absolute() for path in vars(args).values()), 'Use absolute file paths')
        for path in (args.profile, args.private_key):
            release.private_file(path)
        release.private_file(args.output, must_exist=False)
        payload = release.collected_payload(release.read_json(args.profile), release.read_json(args.collection),
                                            args.package, int(time.time()))
        envelope = release.sign(payload, args.private_key, args.openssl, args.output.parent)
        release.write_new(args.output, envelope)
    except (ValueError, TypeError, KeyError, OSError, RecursionError, subprocess.SubprocessError):
        # Do not echo private paths, input values or OpenSSL diagnostics.
        parser.exit(1, 'Release signing failed. Check the private inputs, collection, validity and signing key.\n')
    print('Release metadata signed. Application signing and distribution remain separate gates.')


if __name__ == '__main__':
    main()
