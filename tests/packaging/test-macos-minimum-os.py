#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('gate',ROOT/'scripts/test/check-macos-minimum-os.py')
gate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def binary(major=26, cpu=gate.ARM64, legacy=False):
    command=(struct.pack('<IIII',0x24,16,major<<16,major<<16) if legacy else
             struct.pack('<IIIIII',0x32,24,1,major<<16,major<<16,0))
    return struct.pack('<IIIIIIII',0xfeedfacf,cpu,0,2,1,len(command),0,0)+command


class MinimumOS(unittest.TestCase):
    def test_thin_and_legacy(self):
        self.assertEqual(gate.slices(binary()),[(gate.ARM64,(26,0,0))])
        self.assertEqual(gate.slices(binary(13,legacy=True)),[(gate.ARM64,(13,0,0))])

    def test_fat(self):
        arm=binary()
        intel=binary(13,cpu=0x01000007)
        data=struct.pack('>II',0xcafebabe,2)
        data+=struct.pack('>IIIII',gate.ARM64,0,48,len(arm),0)
        data+=struct.pack('>IIIII',0x01000007,0,48+len(arm),len(intel),0)
        self.assertEqual(len(gate.slices(data+arm+intel)),2)
        with self.assertRaises(ValueError): gate.slices(data+arm)

    def test_fail_closed_on_malformed_metadata(self):
        data=bytearray(binary())
        for payload in [data[:5],data[:-1], data[:32]+struct.pack('<II',0x32,0)+data[40:]]:
            with self.assertRaises(ValueError): gate.slices(payload)
        data[40:44]=struct.pack('<I',2) # iOS is not macOS.
        with self.assertRaises(ValueError): gate.slices(data)

    def test_bundle_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            app=Path(tmp)/'Client.app'
            exe=app/'Contents/MacOS/client'
            exe.parent.mkdir(parents=True)
            exe.write_bytes(binary())
            (app/'Contents/Info.plist').write_bytes(plistlib.dumps({
                'LSMinimumSystemVersion':'26.0','CFBundleExecutable':'client'}))
            self.assertEqual(gate.check(app,'26.0'),1)
            lib=app/'Contents/bundled.dylib'
            lib.write_bytes(binary(27))
            with self.assertRaises(ValueError): gate.check(app,'26.0')
            lib.write_bytes(binary(13,cpu=0x01000007))
            with self.assertRaises(ValueError): gate.check(app,'26.0')
            lib.write_bytes(binary(13))
            self.assertEqual(gate.check(app,'26.0'),2)
            with self.assertRaises(ValueError): gate.check(app,'27.0')
            (app/'escape').symlink_to(Path(tmp))
            with self.assertRaises(ValueError): gate.check(app,'26.0')


if __name__=='__main__': unittest.main()
