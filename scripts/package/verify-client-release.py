#!/usr/bin/env python3
"""Prepare an offline package verification receipt; never install or change state.

Policy and state must come from the trusted operator, independently of the
download. Receipt output is not evidence of Apple signing or notarization.
"""
import argparse
import os
from pathlib import Path
import subprocess
import time

import release_manifest as release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('manifest', 'package', 'policy', 'state', 'openssl', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        release.require(all(path.is_absolute() for path in vars(args).values()), 'Use absolute file paths')
        for path in (args.manifest, args.policy, args.state):
            release.private_file(path)
        release.private_file(args.output, must_exist=False)
        receipt = release.verify(release.read_bytes(args.manifest), args.package, release.read_json(args.policy),
                                 release.read_json(args.state), args.openssl, args.output.parent, int(time.time()))
        release.write_new(args.output, release.canonical(receipt))
    except (ValueError, TypeError, KeyError, OSError, RecursionError, subprocess.SubprocessError):
        parser.exit(1, 'Release verification failed. Check the trusted policy, state, signed metadata and package.\n')
    print('Package metadata and bytes verified. Installation and Apple trust checks were not performed.')


if __name__ == '__main__':
    main()
