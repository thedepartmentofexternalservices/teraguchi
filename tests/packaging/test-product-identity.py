#!/usr/bin/env python3
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('product_identity', ROOT / 'scripts/package/product_identity.py')
IDENTITY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IDENTITY)
SPEC = importlib.util.spec_from_file_location('collector', ROOT / 'scripts/package/collect-package.py')
COLLECTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COLLECTOR)


class ProductIdentityTests(unittest.TestCase):
    def test_rejects_example_profile(self):
        with self.assertRaises(IDENTITY.IdentityError):
            IDENTITY.load(ROOT / 'packaging/client/macos/product-identity.example.json')

    def test_collects_with_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'packaging').mkdir()
            (root / 'packaging/VERSION').write_text('1.2.3\n')
            profile = root / 'identity.json'
            profile.write_text(json.dumps({
                'schema_version': 1,
                'status': 'ready',
                'product': 'teraguchi-client',
                'platform': 'macos',
                'architecture': 'arm64',
                'bundle_id': 'com.studio.teraguchi.client',
                'team_id': 'ABCDE12345',
                'minimum_os': '26.0',
                'display_name': 'Teraguchi',
                'channel': 'candidate',
            }) + '\n', encoding='utf-8')
            subprocess.check_call(['git', '-C', str(root), 'init', '-b', 'main'],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.check_call(['git', '-C', str(root), 'add', 'packaging/VERSION'],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.check_call(['git', '-C', str(root), '-c', 'user.name=Fixture',
                                   '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture'],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            package = root / 'plank-client_1.2.3_arm64.dmg'
            package.write_bytes(b'fixture')
            args = SimpleNamespace(source_root=root, source_commit='HEAD', package=package,
                                   product='client', platform='macos', architecture='arm64',
                                   target_os='macos-26', branch='main', validation='passed',
                                   expected_sha256=None, output_root=None, move=False,
                                   product_identity=profile)
            COLLECTOR.collect(args)
            record = json.loads((root / 'artifacts/packages/releases/1.2.3/manifest.json').read_text())
            self.assertEqual(record['packages'][0]['product_identity']['bundle_id'],
                             'com.studio.teraguchi.client')


if __name__ == '__main__':
    unittest.main()
