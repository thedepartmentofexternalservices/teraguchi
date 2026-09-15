#!/usr/bin/env python3
"""Real Ed25519 operations over synthetic bytes; no real DMGs or installations."""
import base64
import copy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/package'))
import release_manifest as release


def utc(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


class ReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.openssl = Path(os.environ['PLANK_TEST_OPENSSL'])
        cls.temporary = tempfile.TemporaryDirectory(prefix='release-fixtures-')
        cls.directory = Path(cls.temporary.name)
        cls.key = cls.directory / 'release.pem'
        release.crypto(cls.openssl, ['genpkey', '-algorithm', 'ED25519', '-out', str(cls.key)])
        cls.key.chmod(0o600)
        cls.public_key = release.crypto(cls.openssl, ['pkey', '-in', str(cls.key), '-pubout', '-outform', 'DER'])[12:].hex()
        cls.other_key = cls.directory / 'other.pem'
        release.crypto(cls.openssl, ['genpkey', '-algorithm', 'ED25519', '-out', str(cls.other_key)])
        cls.other_key.chmod(0o600)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def setUp(self):
        self.temporary_case = tempfile.TemporaryDirectory(dir=self.directory)
        self.addCleanup(self.temporary_case.cleanup)
        self.case = Path(self.temporary_case.name)
        self.package = self.case / 'plank-client_1.2.3-test-candidate_arm64.dmg'
        self.package.write_bytes(b'Synthetic package bytes, not a disk image or signed application.')
        self.digest, self.size = release.package_digest(self.package)
        self.now = int(time.time())
        self.payload = {
            'schema_version': 1, 'product': 'teraguchi-client', 'bundle_id': 'invalid.example.client',
            'team_id': 'TESTTEAM00', 'platform': 'macos', 'architecture': 'arm64', 'minimum_os': '26.0',
            'studio_public_key': '2' * 64, 'channel': 'candidate', 'sequence': 7,
            'package_version': '1.2.3-test-candidate', 'issued_at': utc(self.now - 60),
            'expires_at': utc(self.now + 3600), 'operation': 'update', 'rollback_from_sha256': '',
            'package_sha256': self.digest, 'package_size': self.size,
            'source': dict(zip(('root', 'client', 'host', 'kymux'), (c * 40 for c in 'abcd')))}
        self.policy = {name: self.payload[name] for name in release.IDENTITY_FIELDS}
        self.policy['release_public_key'] = self.public_key
        self.state = {'schema_version': 1, 'policy_sha256': hashlib.sha256(release.canonical(self.policy)).hexdigest(),
                      'highest_sequence': 0, 'current': None, 'previous': None, 'session_state': 'idle'}
        self.profile = {name: value for name, value in self.payload.items() if name not in ('package_sha256', 'package_size', 'source')}
        self.record = {'path': 'macos/' + self.package.name, 'product': 'client', 'platform': 'macos',
                       'architecture': 'arm64', 'target_os': 'macos-26', 'sha256': self.digest, 'size': self.size,
                       'source_commit': 'a' * 40, 'submodules': {'apps/client': 'b' * 40,
                       'apps/host/linux': 'c' * 40, 'third_party/kyber-kymux': 'd' * 40},
                       'validation': {'package': 'passed', 'functional': 'not-recorded'}}
        self.collection = {'schema_version': 1, 'version': self.payload['package_version'],
                           'branch': 'test-candidate', 'channel': 'candidates', 'packages': [self.record]}

    def envelope(self, payload=None, key=None):
        return release.sign(payload or self.payload, key or self.key, self.openssl, self.case)

    def verify(self, envelope=None, **changes):
        values = dict(envelope=self.envelope() if envelope is None else envelope, package=self.package,
                      policy=self.policy, state=self.state, openssl=self.openssl, temporary_parent=self.case, now=self.now)
        values.update(changes)
        return release.verify(**values)

    def reject_payload(self, **changes):
        with self.assertRaises(ValueError):
            self.verify(self.envelope(dict(self.payload, **changes)))

    def installed(self):
        self.state.update(highest_sequence=6, current={'sha256': 'e' * 64, 'version': '1.2.2-test-candidate'},
                          previous={'sha256': 'f' * 64, 'version': '1.2.1-test-candidate'})

    def test_initial_verification_is_preparation_only(self):
        before = copy.deepcopy(self.state)
        result = self.verify()
        self.assertEqual(result['status'], 'verified')
        self.assertEqual(result['installation'], 'not-performed')
        self.assertEqual(result['apple_signature_and_notarization'], 'not-checked')
        self.assertEqual(result['proposed_state']['session_state'], 'unknown')
        self.assertEqual(result['proposed_state']['current']['sha256'], self.digest)
        self.assertEqual(self.state, before)

    def test_update_retains_previous(self):
        self.installed()
        result = self.verify()
        self.assertEqual(result['proposed_state']['previous'], self.state['current'])
        with self.assertRaisesRegex(ValueError, 'idle'):
            self.verify(state=result['proposed_state'])

    def test_modified_package_bytes_and_size(self):
        envelope = self.envelope()
        for data in (b'x' * self.size, b'short'):
            with self.subTest(size=len(data)), self.assertRaisesRegex(ValueError, 'bytes'):
                self.package.write_bytes(data)
                self.verify(envelope)

    def test_wrong_release_key(self):
        with self.assertRaisesRegex(ValueError, 'signature'):
            self.verify(self.envelope(key=self.other_key))

    def test_modified_signed_payload(self):
        outer = release.decode(self.envelope())
        payload = dict(self.payload, sequence=8)
        outer['payload'] = base64.b64encode(release.canonical(payload)).decode()
        with self.assertRaisesRegex(ValueError, 'signature'):
            self.verify(release.canonical(outer))

    def test_wrong_signature_domain(self):
        message, signature = self.case / 'message', self.case / 'signature'
        message.write_bytes(b'Teraguchi studio setup v1\n' + release.canonical(self.payload))
        release.crypto(self.openssl, ['pkeyutl', '-sign', '-rawin', '-inkey', str(self.key),
                                     '-in', str(message), '-out', str(signature)])
        outer = {'payload': base64.b64encode(release.canonical(self.payload)).decode(),
                 'signature': base64.b64encode(signature.read_bytes()).decode()}
        with self.assertRaisesRegex(ValueError, 'signature'):
            self.verify(release.canonical(outer))

    def test_expired_future_and_overlong_authorization(self):
        for changes in ({'expires_at': utc(self.now)}, {'issued_at': utc(self.now + 1)},
                        {'expires_at': utc(self.now + 31 * 86400)}, {'issued_at': '2026-9-15T00:00:00Z'}):
            with self.subTest(changes=changes):
                self.reject_payload(**changes)

    def test_identity_mismatch(self):
        for name, value in {'product': 'another-client', 'bundle_id': 'invalid.example.other',
                            'team_id': 'OTHERTEAM0', 'platform': 'linux', 'architecture': 'x86_64',
                            'minimum_os': '27.0', 'studio_public_key': '3' * 64, 'channel': 'stable'}.items():
            with self.subTest(field=name):
                self.reject_payload(**{name: value})

    def test_reused_studio_release_key(self):
        with self.assertRaisesRegex(ValueError, 'separate'):
            self.envelope(dict(self.payload, studio_public_key=self.public_key))
        self.policy['studio_public_key'] = self.public_key
        with self.assertRaisesRegex(ValueError, 'separate'):
            self.verify()

    def test_replay_and_old_sequence(self):
        self.installed()
        for sequence in (1, 6):
            with self.subTest(sequence=sequence):
                self.reject_payload(sequence=sequence)

    def test_downgrade_and_already_current(self):
        self.installed()
        self.reject_payload(package_version='1.1.9-test-candidate')
        self.state['current']['sha256'] = self.digest
        with self.assertRaisesRegex(ValueError, 'already current'):
            self.verify()

    def test_stable_same_version_cannot_be_replaced(self):
        self.installed()
        self.policy['channel'] = 'stable'
        self.state['policy_sha256'] = hashlib.sha256(release.canonical(self.policy)).hexdigest()
        self.state['current']['version'] = '1.2.3'
        self.state['previous']['version'] = '1.2.2'
        with self.assertRaisesRegex(ValueError, 'replacement'):
            self.verify(self.envelope(dict(self.payload, channel='stable', package_version='1.2.3')))

    def test_fresh_exact_rollback(self):
        self.installed()
        self.state['current']['version'] = '1.2.4-test-candidate'
        self.state['previous'] = {'sha256': self.digest, 'version': self.payload['package_version']}
        rollback = dict(self.payload, operation='rollback', rollback_from_sha256=self.state['current']['sha256'])
        result = self.verify(self.envelope(rollback))
        self.assertEqual(result['operation'], 'rollback')
        self.assertEqual(result['proposed_state']['previous'], self.state['current'])
        # The old update authorization cannot act as a rollback.
        with self.assertRaisesRegex(ValueError, 'downgrade'):
            self.verify()
        for changes in ({'sequence': 6}, {'rollback_from_sha256': 'a' * 64},
                        {'package_version': '1.2.2-test-candidate'}, {'package_sha256': 'b' * 64}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.verify(self.envelope(dict(rollback, **changes)))

    def test_rollback_requires_retained_previous(self):
        self.installed()
        self.state['previous'] = None
        self.reject_payload(operation='rollback', rollback_from_sha256=self.state['current']['sha256'])

    def test_state_is_bound_to_policy(self):
        self.state['policy_sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'another release policy'):
            self.verify()

    def test_invalid_or_active_state(self):
        for changes in ({'session_state': 'active'}, {'session_state': 'unknown'}, {'highest_sequence': True},
                        {'highest_sequence': 7}, {'current': {'sha256': 'e' * 64, 'version': '1.2.2'}}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.verify(state=dict(self.state, **changes))
        self.installed()
        self.state['previous'] = self.state['current']
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            self.verify()

    def test_history_channel_mismatch(self):
        self.installed()
        self.state['current']['version'] = '1.2.2'
        with self.assertRaisesRegex(ValueError, 'another channel'):
            self.verify()

    def test_strict_schema_and_provenance(self):
        for changes in ({'schema_version': True}, {'sequence': True}, {'sequence': 0}, {'sequence': 2147483648},
                        {'unexpected': 1}, {'source': {'root': 'a' * 40}}, {'package_size': True},
                        {'package_version': '01.2.3-test-candidate'}, {'rollback_from_sha256': 'a' * 64}):
            with self.subTest(changes=changes):
                self.reject_payload(**changes)

    def test_strict_json_and_base64(self):
        outer = release.decode(self.envelope())
        bad = [b'{}', b'[]', b'{"payload":"a","payload":"b"}', b'{"a":NaN}', b'x' * (release.MAX_JSON + 1),
               json.dumps(outer, indent=2).encode(), release.canonical(dict(outer, signature='%%%')),
               release.canonical(dict(outer, payload=outer['payload'] + '\n'))]
        for envelope in bad:
            with self.subTest(size=len(envelope)), self.assertRaises(ValueError):
                self.verify(envelope)

    def test_signed_noncanonical_payload(self):
        data = json.dumps(self.payload, indent=2).encode()
        message, signature = self.case / 'message', self.case / 'signature'
        message.write_bytes(release.DOMAIN + data)
        release.crypto(self.openssl, ['pkeyutl', '-sign', '-rawin', '-inkey', str(self.key),
                                     '-in', str(message), '-out', str(signature)])
        outer = {'payload': base64.b64encode(data).decode(), 'signature': base64.b64encode(signature.read_bytes()).decode()}
        with self.assertRaisesRegex(ValueError, 'Noncanonical'):
            self.verify(release.canonical(outer))

    def test_nonregular_package_and_json_rejected(self):
        link = self.case / 'link'
        link.symlink_to(self.package)
        fifo = self.case / 'fifo'
        os.mkfifo(fifo, 0o600)
        for path in (link, fifo, self.case):
            with self.subTest(kind=path.name):
                with self.assertRaises((ValueError, OSError)):
                    release.package_digest(path)
                with self.assertRaises((ValueError, OSError)):
                    release.read_json(path)

    def test_private_file_and_output_protection(self):
        private = self.case / 'private.json'
        release.write_new(private, b'{}')
        self.assertEqual(private.stat().st_mode & 0o777, 0o600)
        release.private_file(private)
        with self.assertRaises(FileExistsError):
            release.write_new(private, b'overwritten')
        private.chmod(0o644)
        with self.assertRaises(ValueError):
            release.private_file(private)
        with self.assertRaises(ValueError):
            release.private_file(ROOT / 'release-fixture.json', must_exist=False)

    def test_collection_binds_exact_source_and_bytes(self):
        self.assertEqual(release.collected_payload(self.profile, self.collection, self.package, self.now), self.payload)
        for changes in ({'sha256': '0' * 64}, {'size': self.size + 1}, {'target_os': 'macos-27'},
                        {'product': 'host'}, {'submodules': {}}, {'validation': {'package': 'not-recorded'}}):
            collection = dict(self.collection, packages=[dict(self.record, **changes)])
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                release.collected_payload(self.profile, collection, self.package, self.now)

    def test_collection_rejects_ambiguous_or_relabelled_records(self):
        for changes in ({'packages': [self.record, self.record]}, {'version': '1.2.4-test-candidate'},
                        {'branch': 'another'}, {'channel': 'releases'}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                release.collected_payload(self.profile, dict(self.collection, **changes), self.package, self.now)

    def test_cli_sign_verify_no_state_write_or_overwrite(self):
        paths = {name: self.case / (name + '.json') for name in ('profile', 'collection', 'policy', 'state', 'manifest', 'receipt')}
        for name in ('profile', 'collection', 'policy', 'state'):
            release.write_new(paths[name], release.canonical(getattr(self, name)))
        state_before = paths['state'].read_bytes()
        sign = [sys.executable, '-B', str(ROOT / 'scripts/package/sign-client-release.py'),
                '--profile', str(paths['profile']), '--collection', str(paths['collection']), '--package', str(self.package),
                '--private-key', str(self.key), '--openssl', str(self.openssl), '--output', str(paths['manifest'])]
        verify = [sys.executable, '-B', str(ROOT / 'scripts/package/verify-client-release.py'),
                  '--manifest', str(paths['manifest']), '--package', str(self.package), '--policy', str(paths['policy']),
                  '--state', str(paths['state']), '--openssl', str(self.openssl), '--output', str(paths['receipt'])]
        for command in (sign, verify):
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(paths['state'].read_bytes(), state_before)
        self.assertEqual(release.read_json(paths['receipt'])['installation'], 'not-performed')
        for name in ('manifest', 'receipt'):
            self.assertEqual(paths[name].stat().st_mode & 0o777, 0o600)
        for command in (sign, verify):
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn(str(self.case), result.stdout + result.stderr)
        # Failure before receipt creation, with no private contents in diagnostics.
        paths['receipt'].unlink()
        self.package.write_bytes(b'PRIVATE SYNTHETIC CANARY')
        result = subprocess.run(verify, capture_output=True, text=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(paths['receipt'].exists())
        self.assertNotIn('PRIVATE SYNTHETIC CANARY', result.stdout + result.stderr)
        self.assertNotIn(str(self.case), result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
