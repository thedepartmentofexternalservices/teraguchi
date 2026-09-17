"""Offline release verification primitives; no downloader or installer.

The caller supplies independently trusted release policy and installation state.
A verified result is a preparation receipt, never evidence of an installation.
"""
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile

DOMAIN = b'Teraguchi client release v1\n'
PUBLIC_DER_PREFIX = bytes.fromhex('302a300506032b6570032100')
MAX_JSON = 32768
MAX_PACKAGE = 8 * 1024**3
IDENTITY_FIELDS = {'product', 'bundle_id', 'team_id', 'platform', 'architecture',
                   'minimum_os', 'studio_public_key', 'channel'}
FIELDS = IDENTITY_FIELDS | {'schema_version', 'sequence', 'package_version', 'issued_at',
    'expires_at', 'operation', 'rollback_from_sha256', 'package_sha256', 'package_size', 'source'}


class VerificationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def unique(pairs):
    result = {}
    for name, value in pairs:
        require(name not in result, 'Duplicate JSON field')
        result[name] = value
    return result


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def decode(raw, canonical_required=False):
    require(0 < len(raw) <= MAX_JSON, 'Invalid JSON size')
    result = json.loads(raw, object_pairs_hook=unique,
                        parse_constant=lambda _: (_ for _ in ()).throw(VerificationError('Invalid JSON number')))
    if canonical_required:
        require(canonical(result) == raw.strip(), 'Noncanonical signed JSON')
    return result


def read_bytes(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as source:
        require(stat.S_ISREG(os.fstat(source.fileno()).st_mode), 'Expected a regular JSON file')
        raw = source.read(MAX_JSON + 1)
        require(0 < len(raw) <= MAX_JSON, 'Invalid JSON size')
        return raw


def read_json(path):
    return decode(read_bytes(path))


def hex_value(value, size=64):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{' + str(size) + '}', value) is not None


def package_version(value):
    require(isinstance(value, str) and len(value) <= 100, 'Invalid package version')
    match = re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([a-z0-9][a-z0-9-]{0,63}))?', value)
    require(match is not None, 'Invalid package version')
    return tuple(int(match[i]) for i in (1, 2, 3)), bool(match[4])


def timestamp(value):
    require(isinstance(value, str), 'Invalid validity timestamp')
    parsed = datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    require(parsed.strftime('%Y-%m-%dT%H:%M:%SZ') == value, 'Noncanonical validity timestamp')
    return int(parsed.timestamp())


def validate_identity(value):
    require(value['product'] == 'teraguchi-client' and value['platform'] == 'macos'
            and value['architecture'] == 'arm64', 'Wrong product or platform')
    require(isinstance(value['bundle_id'], str) and
            re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*){2,5}', value['bundle_id']),
            'Invalid bundle identity')
    require(isinstance(value['team_id'], str) and re.fullmatch(r'[A-Z0-9]{10}', value['team_id']),
            'Invalid Developer ID team')
    require(isinstance(value['minimum_os'], str) and re.fullmatch(r'[1-9][0-9]*\.[0-9]+', value['minimum_os']),
            'Invalid minimum OS')
    require(hex_value(value['studio_public_key']), 'Missing studio verification key')
    require(value['channel'] in ('candidate', 'stable'), 'Invalid release channel')


def validate_payload(value, now):
    require(isinstance(value, dict) and set(value) == FIELDS, 'Unsupported release fields')
    require(type(value['schema_version']) is int and value['schema_version'] == 1, 'Invalid release schema')
    require(type(value['sequence']) is int and 1 <= value['sequence'] <= 2147483647, 'Invalid release sequence')
    validate_identity(value)
    _, prerelease = package_version(value['package_version'])
    require(prerelease == (value['channel'] == 'candidate'), 'Version and channel disagree')
    issued, expires = timestamp(value['issued_at']), timestamp(value['expires_at'])
    require(0 < issued <= now < expires and 0 < expires - issued <= 30 * 86400, 'Release is not currently valid')
    require(value['operation'] in ('update', 'rollback'), 'Unsupported release operation')
    require(hex_value(value['rollback_from_sha256']) if value['operation'] == 'rollback'
            else value['rollback_from_sha256'] == '', 'Invalid rollback authorization')
    require(hex_value(value['package_sha256']) and type(value['package_size']) is int and
            0 < value['package_size'] <= MAX_PACKAGE, 'Invalid package digest or size')
    require(isinstance(value['source'], dict) and set(value['source']) == {'root', 'client', 'host', 'kymux'}
            and all(hex_value(pin, 40) for pin in value['source'].values()), 'Incomplete source provenance')


def package_digest(path):
    # A receipt binds these bytes; an eventual installer must reverify at use.
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as source:
        before = os.fstat(source.fileno())
        require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= MAX_PACKAGE, 'Invalid package file')
        digest = hashlib.sha256()
        count = 0
        for block in iter(lambda: source.read(1024 * 1024), b''):
            count += len(block)
            require(count <= before.st_size, 'Package grew during verification')
            digest.update(block)
        after = os.fstat(source.fileno())
        require(count == before.st_size and (before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                (after.st_size, after.st_mtime_ns, after.st_ctime_ns), 'Package changed during verification')
        return digest.hexdigest(), after.st_size


def crypto(openssl, args):
    result = subprocess.run([str(openssl), *args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, stdin=subprocess.DEVNULL, timeout=30)
    require(result.returncode == 0, 'Release signature operation failed')
    return result.stdout


def sign(payload, private_key, openssl, temporary_parent):
    data = canonical(payload)
    with tempfile.TemporaryDirectory(prefix='release-sign-', dir=temporary_parent) as temporary:
        directory = Path(temporary)
        public = crypto(openssl, ['pkey', '-in', str(private_key), '-pubout', '-outform', 'DER'])
        require(len(public) == 44 and public.startswith(PUBLIC_DER_PREFIX), 'Ed25519 release key required')
        require(public[12:].hex() != payload['studio_public_key'], 'Use a separate release signing key')
        (directory / 'message').write_bytes(DOMAIN + data)
        crypto(openssl, ['pkeyutl', '-sign', '-rawin', '-inkey', str(private_key),
                        '-in', str(directory / 'message'), '-out', str(directory / 'signature')])
        signature = (directory / 'signature').read_bytes()
        require(len(signature) == 64, 'Invalid signature length')
    envelope = canonical({'payload': base64.b64encode(data).decode(),
                          'signature': base64.b64encode(signature).decode()})
    require(len(envelope) <= MAX_JSON, 'Release manifest is too large')
    return envelope


def verified_payload(envelope, public_key, openssl, temporary_parent, now):
    outer = decode(envelope, True)
    require(isinstance(outer, dict) and set(outer) == {'payload', 'signature'}, 'Invalid signed envelope')
    decoded = {}
    for name in ('payload', 'signature'):
        require(isinstance(outer[name], str), 'Invalid signature encoding')
        decoded[name] = base64.b64decode(outer[name], validate=True)
        require(base64.b64encode(decoded[name]).decode() == outer[name], 'Noncanonical signature encoding')
    require(hex_value(public_key) and len(decoded['signature']) == 64, 'Invalid release verification key/signature')
    with tempfile.TemporaryDirectory(prefix='release-verify-', dir=temporary_parent) as temporary:
        directory = Path(temporary)
        (directory / 'public.der').write_bytes(PUBLIC_DER_PREFIX + bytes.fromhex(public_key))
        (directory / 'message').write_bytes(DOMAIN + decoded['payload'])
        (directory / 'signature').write_bytes(decoded['signature'])
        crypto(openssl, ['pkeyutl', '-verify', '-rawin', '-pubin', '-inkey', str(directory / 'public.der'),
                        '-keyform', 'DER', '-sigfile', str(directory / 'signature'), '-in', str(directory / 'message')])
    payload = decode(decoded['payload'], True)
    # Payload has no optional surrounding whitespace, even with a valid signature.
    require(canonical(payload) == decoded['payload'], 'Noncanonical release payload')
    validate_payload(payload, now)
    return payload


def validate_state(state):
    require(isinstance(state, dict) and set(state) == {'schema_version', 'policy_sha256', 'highest_sequence', 'current', 'previous', 'session_state'},
            'Invalid installation state')
    require(hex_value(state['policy_sha256']), 'Missing installation policy binding')
    require(type(state['schema_version']) is int and state['schema_version'] == 1 and
            type(state['highest_sequence']) is int and 0 <= state['highest_sequence'] <= 2147483647,
            'Invalid release history')
    require(state['session_state'] == 'idle', 'Installation requires a confirmed idle session')
    for name in ('current', 'previous'):
        entry = state[name]
        if entry is None:
            continue
        require(isinstance(entry, dict) and set(entry) == {'sha256', 'version'} and hex_value(entry['sha256']),
                'Invalid retained package record')
        package_version(entry['version'])
    require(state['current'] is not None or (state['previous'] is None and state['highest_sequence'] == 0),
            'Inconsistent installation history')
    require(state['current'] is None or state['highest_sequence'] > 0, 'Missing release history')
    require(state['previous'] is None or state['previous']['sha256'] != state['current']['sha256'],
            'Ambiguous previous package')


def verify(envelope, package, policy, state, openssl, temporary_parent, now):
    require(isinstance(policy, dict) and set(policy) == IDENTITY_FIELDS | {'release_public_key'}, 'Invalid trusted release policy')
    validate_identity(policy)
    require(policy['release_public_key'] != policy['studio_public_key'], 'Use a separate release signing key')
    payload = verified_payload(envelope, policy['release_public_key'], openssl, temporary_parent, now)
    require(all(payload[name] == policy[name] for name in IDENTITY_FIELDS), 'Release identity does not match trusted policy')
    validate_state(state)
    policy_digest = hashlib.sha256(canonical(policy)).hexdigest()
    require(state['policy_sha256'] == policy_digest, 'Installation state belongs to another release policy')
    require(payload['sequence'] > state['highest_sequence'], 'Release replay or older authorization rejected')
    current, previous = state['current'], state['previous']
    for entry in (current, previous):
        require(entry is None or package_version(entry['version'])[1] == (policy['channel'] == 'candidate'),
                'Installation history belongs to another channel')
    if payload['operation'] == 'rollback':
        require(current is not None and previous is not None and
                payload['rollback_from_sha256'] == current['sha256'] and
                payload['package_sha256'] == previous['sha256'] and
                payload['package_version'] == previous['version'], 'Rollback does not match the retained previous package')
    elif current is not None:
        require(package_version(payload['package_version'])[0] >= package_version(current['version'])[0],
                'Package version downgrade rejected')
        require(policy['channel'] != 'stable' or payload['package_version'] != current['version'],
                'Stable version replacement rejected')
        require(payload['package_sha256'] != current['sha256'], 'Package is already current')
    digest, size = package_digest(package)
    require(digest == payload['package_sha256'] and size == payload['package_size'], 'Package bytes differ from signed release')
    return {'schema_version': 1, 'status': 'verified', 'installation': 'not-performed',
            'verification_time': now, 'authorization_expires_at': payload['expires_at'],
            'apple_signature_and_notarization': 'not-checked',
            'manifest_sha256': hashlib.sha256(envelope).hexdigest(),
            'package_sha256': digest, 'package_size': size, 'source': payload['source'],
            'identity': {name: payload[name] for name in sorted(IDENTITY_FIELDS)},
            'operation': payload['operation'],
            'proposed_state': {'schema_version': 1, 'policy_sha256': policy_digest,
                               'highest_sequence': payload['sequence'],
                               'current': {'sha256': digest, 'version': payload['package_version']},
                               'previous': current, 'session_state': 'unknown'}}


def collected_payload(profile, collection, package, now):
    """Bind operator declarations to one exact existing collector record.

    Collector validation is a recorded build assertion, not an Apple signature
    check. These routines never mount or execute a package.
    """
    require(isinstance(profile, dict) and set(profile) == FIELDS - {'package_sha256', 'package_size', 'source'},
            'Invalid release signing profile')
    require(isinstance(collection, dict) and set(collection) == {'schema_version', 'version', 'branch', 'channel', 'packages'}
            and type(collection['schema_version']) is int and collection['schema_version'] == 1,
            'Invalid package collection')
    require(collection['version'] == profile['package_version'] and
            collection['channel'] == ('candidates' if profile['channel'] == 'candidate' else 'releases'),
            'Collection version/channel does not match release')
    branch = collection['branch']
    require(isinstance(branch, str) and re.fullmatch(r'[a-z0-9][a-z0-9-]*', branch), 'Invalid collection branch')
    require((profile['channel'] == 'stable' and branch == 'main') or
            (profile['channel'] == 'candidate' and branch != 'main' and
             profile['package_version'].split('-', 1)[-1] == branch), 'Collection branch does not match release')
    expected_name = 'plank-client_' + profile['package_version'] + '_arm64.dmg'
    require(package.name == expected_name, 'Package filename disagrees with collection')
    records = collection['packages']
    require(isinstance(records, list) and 1 <= len(records) <= 32 and all(isinstance(record, dict) for record in records),
            'Invalid package collection records')
    matches = [record for record in records if record.get('path') == 'macos/' + expected_name]
    require(len(matches) == 1, 'Expected one exact Mac client collection record')
    record = matches[0]
    require((record.get('product'), record.get('platform'), record.get('architecture')) == ('client', 'macos', 'arm64'),
            'Collection product/platform mismatch')
    validate_identity(profile)
    require(record.get('target_os') == 'macos-' + profile['minimum_os'].split('.')[0], 'Collection OS baseline mismatch')
    require(isinstance(record.get('validation'), dict) and record['validation'].get('package') == 'passed',
            'Package validation was not recorded as passed')
    digest, size = package_digest(package)
    require(record.get('sha256') == digest and type(record.get('size')) is int and record['size'] == size,
            'Package bytes differ from collected package')
    submodules = record.get('submodules')
    require(isinstance(submodules, dict), 'Missing collected source pins')
    payload = dict(profile, package_sha256=digest, package_size=size,
                   source={'root': record.get('source_commit'), 'client': submodules.get('apps/client'),
                           'host': submodules.get('apps/host/linux'), 'kymux': submodules.get('third_party/kyber-kymux')})
    validate_payload(payload, now)
    return payload


def private_file(path, must_exist=True):
    require(path.is_absolute() and not path.is_symlink(), 'Use an absolute regular private file')
    resolved = path.resolve()
    result = subprocess.run(['git', '-C', str(resolved.parent), 'rev-parse', '--show-toplevel'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    require(result.returncode != 0, 'Keep release policy, keys and receipts outside Git')
    require(path.parent.is_dir() and path.parent.stat().st_uid == os.getuid() and
            not path.parent.stat().st_mode & 0o077, 'Use an owner-only private directory')
    if must_exist:
        info = path.stat()
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and not info.st_mode & 0o077,
                'Use an owner-only regular private file')
    else:
        require(not path.exists(), 'Refusing to overwrite receipt or signed manifest')


def write_new(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(data + b'\n')
        stream.flush()
        os.fsync(stream.fileno())
