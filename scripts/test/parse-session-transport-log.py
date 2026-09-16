#!/usr/bin/env python3
"""Extract coarse native transport counters from a private PLANK client log excerpt.

The parser reads one PlankTransport teardown summary line and optional toolbar-era
session notes. It does not upload data or modify the source log. Output is suitable
for merging into a P4 evidence manifest; it is not pen-to-picture latency proof.
"""
import argparse
import json
import re
import sys
from pathlib import Path

SUMMARY = re.compile(
    r'PlankTransport native transport: .*?'
    r'QUIC-RTT-us=(?P<rtt>\d+).*?'
    r'video-FEC-source-symbols=(?P<fec_source>\d+).*?'
    r'video-FEC-source-symbols-missing=(?P<fec_missing>\d+).*?'
    r'video-FEC-source-symbols-unrecovered=(?P<fec_unrecovered>\d+)'
)


def parse_text(text):
    match = None
    for line in text.splitlines():
        candidate = SUMMARY.search(line)
        if candidate:
            match = candidate
    if match is None:
        raise ValueError('No PlankTransport native transport summary line found')
    rtt_us = int(match.group('rtt'))
    fec_source = int(match.group('fec_source'))
    fec_missing = int(match.group('fec_missing'))
    fec_unrecovered = int(match.group('fec_unrecovered'))
    before = after = None
    if fec_source > 0:
        before = round(fec_missing * 100.0 / fec_source, 2)
        after = round(fec_unrecovered * 100.0 / fec_source, 2)
    return {
        'network_rtt_ms_final': (rtt_us + 500) // 1000 if rtt_us else None,
        'quic_rtt_us_final': rtt_us,
        'video_fec_source_symbols_final': fec_source,
        'video_fec_source_symbols_missing_final': fec_missing,
        'video_fec_source_symbols_unrecovered_final': fec_unrecovered,
        'pre_fec_loss_percent_final': before,
        'post_fec_loss_percent_final': after,
        'notes': 'Final native transport counters from one session teardown log line.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path, help='private client log file or excerpt')
    parser.add_argument('--output', type=Path, help='optional JSON output path')
    args = parser.parse_args()
    if args.output and args.output.exists():
        parser.error('output already exists')
    try:
        summary = parse_text(args.log.read_text(encoding='utf-8', errors='replace'))
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    encoded = json.dumps(summary, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.write_text(encoded, encoding='utf-8')
        args.output.chmod(0o600)
        print(args.output)
    else:
        print(encoded, end='')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
