#!/usr/bin/env python3
"""Package only authentic, current setup matching the compiled client key."""
import base64
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
OPENSSL = os.environ.get('PLANK_OPENSSL')


@unittest.skipUnless(OPENSSL, 'Set PLANK_OPENSSL to the pinned OpenSSL executable')
class BundledSetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='studio-package-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.app = self.directory/'Example.app'
        (self.app/'Contents/Resources').mkdir(parents=True)
        self.plist = self.app/'Contents/Info.plist'
        self.plist.write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.example.client'}))
        self.key = self.directory/'key.pem'
        subprocess.run([OPENSSL,'genpkey','-algorithm','ED25519','-out',str(self.key)],check=True)
        public = subprocess.check_output([OPENSSL,'pkey','-in',str(self.key),'-pubout','-outform','DER'])
        self.header = self.directory/'key.h'
        self.header.write_text('#pragma once\n#define TERAGUCHI_STUDIO_KEY_HEX "'+public[-32:].hex()+'"\n')
        now = datetime.now(timezone.utc).replace(microsecond=0)
        iso = lambda t:t.strftime('%Y-%m-%dT%H:%M:%SZ')
        self.profile = {'version':2,'revision':1,'label':'Example Studio','dns_suffix':'studio-example.ts.net',
            'issued_at':iso(now-timedelta(minutes=1)), 'expires_at':iso(now+timedelta(hours=1)),
            'workstations':[{'node_id':'node-a','host_id':'host-a','certificate_sha256':['a'*64]}]}
        self.setup = self.directory/'setup.teraguchi-studio'
        self.destination = self.app/'Contents/Resources/studio-setup.teraguchi-studio'
        self.sign()

    def sign(self):
        content = json.dumps(self.profile,sort_keys=True,separators=(',',':')).encode()
        message, signature = self.directory/'message', self.directory/'signature'
        message.write_bytes(b'Teraguchi studio setup v1\n'+content)
        subprocess.run([OPENSSL,'pkeyutl','-sign','-rawin','-inkey',str(self.key),'-in',str(message),'-out',str(signature)],check=True)
        self.setup.write_text(json.dumps({'payload':base64.b64encode(content).decode(),
            'signature':base64.b64encode(signature.read_bytes()).decode()},sort_keys=True,separators=(',',':'))+'\n')

    def stage(self, setup=None):
        return subprocess.run([sys.executable,str(ROOT/'scripts/package/stage-studio-setup.py'),
            '--app',str(self.app),'--setup',str(self.setup if setup is None else setup),
            '--key-header',str(self.header),'--openssl',OPENSSL],capture_output=True,text=True)

    def test_matching_signed_setup_is_bundled(self):
        result = self.stage()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.destination.read_bytes(),self.setup.read_bytes())
        self.assertTrue(plistlib.loads(self.plist.read_bytes())['TeraguchiWorkstationPicker'])
        self.assertEqual(self.destination.stat().st_mode & 0o777,0o644)

    def test_wrong_build_key_is_rejected(self):
        self.header.write_text('#define TERAGUCHI_STUDIO_KEY_HEX "'+'b'*64+'"\n')
        self.assertNotEqual(self.stage().returncode,0)
        self.assertFalse(self.destination.exists())

    def test_tampered_payload_is_rejected(self):
        envelope = json.loads(self.setup.read_text())
        self.profile['label'] = 'Changed'
        envelope['payload'] = base64.b64encode(json.dumps(self.profile,sort_keys=True,separators=(',',':')).encode()).decode()
        self.setup.write_text(json.dumps(envelope,sort_keys=True,separators=(',',':')))
        self.assertNotEqual(self.stage().returncode,0)

    def test_expired_profile_is_rejected(self):
        self.profile['issued_at']='2020-01-01T00:00:00Z'
        self.profile['expires_at']='2020-01-02T00:00:00Z'
        self.sign()
        self.assertNotEqual(self.stage().returncode,0)

    def test_discovery_only_setup_is_rejected(self):
        self.profile['version']=1; del self.profile['workstations']; self.sign()
        self.assertNotEqual(self.stage().returncode,0)

    def test_symlink_input_is_rejected(self):
        link = self.directory/'linked-setup'; link.symlink_to(self.setup)
        self.assertNotEqual(self.stage(link).returncode,0)

    def test_omitted_setup_removes_retained_copy(self):
        self.assertEqual(self.stage().returncode,0)
        self.assertEqual(self.stage('').returncode,0)
        self.assertFalse(self.destination.exists())
        self.assertNotIn('TeraguchiWorkstationPicker',plistlib.loads(self.plist.read_bytes()))


if __name__ == '__main__':
    unittest.main()
