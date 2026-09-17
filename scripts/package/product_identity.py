"""Validate Teraguchi Mac client product identity profiles for packaging."""
import json
import re
from pathlib import Path

REQUIRED = {
    'schema_version', 'product', 'platform', 'architecture', 'bundle_id',
    'team_id', 'minimum_os', 'display_name', 'channel',
}


class IdentityError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise IdentityError(message)


def load(path):
    raw = Path(path).read_text(encoding='utf-8')
    if len(raw) > 32768:
        raise IdentityError('Product identity profile is too large')
    profile = json.loads(raw)
    require(isinstance(profile, dict), 'Product identity profile must be a JSON object')
    require(set(profile) >= REQUIRED, 'Product identity profile is missing required fields')
    require(profile.get('schema_version') == 1, 'Unsupported product identity schema')
    require(profile.get('status') != 'example-only', 'Replace example-only product identity before use')
    require(profile['product'] == 'teraguchi-client', 'Wrong product name')
    require(profile['platform'] == 'macos' and profile['architecture'] == 'arm64', 'Wrong platform')
    require(profile['channel'] in ('candidate', 'stable'), 'Invalid release channel')
    require(isinstance(profile['display_name'], str) and 1 <= len(profile['display_name']) <= 64,
            'Invalid display name')
    require(re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*){2,5}', profile['bundle_id']),
            'Invalid bundle identifier')
    require(re.fullmatch(r'[A-Z0-9]{10}', profile['team_id']), 'Invalid Developer ID team')
    require(re.fullmatch(r'[1-9][0-9]*\.[0-9]+', profile['minimum_os']), 'Invalid minimum OS')
    if 'example' in profile['bundle_id'].lower():
        raise IdentityError('Bundle identifier still contains an example placeholder')
    return profile


def manifest_block(profile):
    return {
        'product': profile['product'],
        'display_name': profile['display_name'],
        'bundle_id': profile['bundle_id'],
        'team_id': profile['team_id'],
        'minimum_os': profile['minimum_os'],
        'channel': profile['channel'],
        'collector_filename': 'plank-client',
    }
