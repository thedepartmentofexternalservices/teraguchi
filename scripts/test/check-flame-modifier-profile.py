#!/usr/bin/env python3
"""Check a draft modifier map against saved Flame shortcuts. Never applies input."""
import argparse
import json
from pathlib import Path
import re
import sys

MODIFIERS = tuple('KEY_' + name for name in (
    'LEFTSHIFT', 'RIGHTSHIFT', 'LEFTCTRL', 'RIGHTCTRL',
    'LEFTALT', 'RIGHTALT', 'LEFTMETA', 'RIGHTMETA',
))


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON field')
        result[key] = value
    return result


def load_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=unique_object)


def validate_profile(profile):
    if not isinstance(profile, dict) or set(profile) != {'schema', 'name', 'mapping'}:
        raise ValueError('profile requires schema, name and mapping only')
    if profile['schema'] != 'teraguchi.input.modifier-profile-draft/1':
        raise ValueError('unsupported draft profile schema')
    if not isinstance(profile['name'], str) or not re.fullmatch(r'[a-z][a-z0-9-]{0,63}', profile['name']):
        raise ValueError('profile name must be a short lowercase identifier')
    mapping = profile['mapping']
    if not isinstance(mapping, dict) or set(mapping) != set(MODIFIERS):
        raise ValueError('mapping must name all eight physical modifiers exactly once')
    if any(not isinstance(target, str) or target not in MODIFIERS for target in mapping.values()):
        raise ValueError('mapping targets must be side-specific modifiers')
    # Require a permutation: no collapsed keys and no lost Super/Alt/Control side.
    # A global Command->Control substitution fails here even before an artist test.
    if set(mapping.values()) != set(MODIFIERS):
        missing = ', '.join(key for key in MODIFIERS if key not in mapping.values())
        raise ValueError('modifier collision; unreachable host modifiers: ' + missing)
    return mapping


def validate_shortcuts(baseline):
    if not isinstance(baseline, dict) or baseline.get('schema') != 'teraguchi.input.shortcut-draft/1':
        raise ValueError('unsupported shortcut fixture schema')
    if baseline.get('status') != 'DRAFT_NOT_EXECUTED':
        raise ValueError('this checker accepts draft fixtures, not hardware evidence')
    cases = baseline.get('cases')
    if not isinstance(cases, list) or not cases:
        raise ValueError('shortcut fixture must contain cases')
    ids = set()
    for case in cases:
        if not isinstance(case, dict) or not isinstance(case.get('id'), str):
            raise ValueError('shortcut requires an identifier')
        if not re.fullmatch(r'[a-z][a-z0-9_]{0,63}', case['id']) or case['id'] in ids:
            raise ValueError('invalid or duplicate shortcut identifier')
        ids.add(case['id'])
        events = case.get('expected_host_key_events')
        if not isinstance(events, list) or not events:
            raise ValueError('shortcut requires an ordered event sequence')
        held = []
        for event in events:
            if not isinstance(event, dict) or set(event) != {'key', 'value'}:
                raise ValueError('each shortcut event requires key and value only')
            key, value = event['key'], event['value']
            if not isinstance(key, str) or not re.fullmatch(r'KEY_[A-Z0-9_]{1,32}', key):
                raise ValueError('invalid Linux key name')
            if type(value) is not int or value not in (0, 1):
                raise ValueError('event value must be integer down=1 or up=0')
            if value == 1:
                if key in held:
                    raise ValueError('duplicate key down in shortcut fixture')
                held.append(key)
            elif not held or held.pop() != key:
                raise ValueError('shortcut releases must reverse their press order')
        if held:
            raise ValueError('shortcut leaves keys held')
    return cases


def analyze(profile, baseline):
    mapping = validate_profile(profile)
    cases = validate_shortcuts(baseline)
    inverse = {target: source for source, target in mapping.items()}
    results = []
    for case in cases:
        host_events = case['expected_host_key_events']
        physical = [{'key': inverse.get(event['key'], event['key']), 'value': event['value']}
                    for event in host_events]
        # Substitute once, simultaneously. Do not follow a swap as a mapping chain.
        replay = [{'key': mapping.get(event['key'], event['key']), 'value': event['value']}
                  for event in physical]
        if replay != host_events:
            raise ValueError('profile cannot reproduce the ordered shortcut')
        results.append({'id': case['id'], 'physical_key_events': physical})
    return {'status': 'DRAFT_STATIC_CHECK_PASSED', 'profile': profile['name'],
            'hardware_qualified': False, 'runtime_profile_applied': False, 'cases': results}


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', type=Path, default=root / 'tests/input/fixtures/modifiers-physical-identity.json')
    parser.add_argument('--shortcuts', type=Path, default=root / 'tests/input/fixtures/flame-smoke-classic-shortcuts.json')
    args = parser.parse_args()
    try:
        result = analyze(load_json(args.profile), load_json(args.shortcuts))
    except (ValueError, OSError) as error:
        # A filesystem exception may contain private paths; keep it out of reports.
        detail = 'cannot read input file' if isinstance(error, OSError) else str(error)
        print('DRAFT_STATIC_CHECK_FAILED: ' + detail, file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
