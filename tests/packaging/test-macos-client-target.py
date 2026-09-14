#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
HELPER=ROOT/'scripts/build/macos-client-target.sh'


class ClientTarget(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base=Path(self.temporary.name)
        self.bin=self.base/'bin'
        self.bin.mkdir()
        for name,body in {
            'uname':'#!/bin/sh\ncase "$1" in -s) echo Darwin;; -m) echo arm64;; *) exit 2;; esac\n',
            'xcrun':'#!/bin/sh\ncase "$*" in "--sdk macosx --show-sdk-version") echo "$TEST_SDK";; "--sdk macosx --show-sdk-path") echo /sdk;; *) exit 2;; esac\n',
        }.items():
            p=self.bin/name;p.write_text(body);p.chmod(0o700)
        self.env=dict(os.environ)
        for key in ['MACOSX_DEPLOYMENT_TARGET','PLANK_MACOS_CLIENT_TARGET','SDKROOT']:
            self.env.pop(key,None)
        self.env.update(PATH=str(self.bin)+':'+self.env['PATH'],TEST_SDK='26.5',
                        PLANK_MAC_CLIENT_DEPS=str(self.base/'dependencies'))

    def run_helper(self,tail='',**changes):
        env=dict(self.env);env.update(changes)
        script='set -eu\nsource "$1"\nplank_macos_client_target\n'+tail
        return subprocess.run(['bash','-c',script,'test',str(HELPER),str(ROOT)],
                              env=env,capture_output=True,text=True)

    def test_target_and_sdk_matrix(self):
        for target,sdk,accepted in [('26.0','26.5',True),('26.0','27.0',True),
                                   ('27.0','27.0',True),('27.0','26.5',False),
                                   ('26.0','15.2',False),('25.0','26.5',False)]:
            with self.subTest(target=target,sdk=sdk):
                result=self.run_helper('printf "%s" "$MACOSX_DEPLOYMENT_TARGET"',
                        PLANK_MACOS_CLIENT_TARGET=target,TEST_SDK=sdk)
                self.assertEqual(result.returncode==0,accepted,result.stderr)
                if accepted:self.assertEqual(result.stdout,target)

    def test_conflicting_target_fails(self):
        self.assertNotEqual(self.run_helper(MACOSX_DEPLOYMENT_TARGET='27.0').returncode,0)

    def test_profile_rejects_cross_target_and_cross_sdk_reuse(self):
        prepare='plank_macos_client_dependency_profile bootstrap "$2"'
        verify='plank_macos_client_dependency_profile build "$2"'
        self.assertEqual(self.run_helper(prepare).returncode,0)
        self.assertEqual(self.run_helper(verify).returncode,0)
        self.assertNotEqual(self.run_helper(verify,TEST_SDK='26.6').returncode,0)
        self.assertNotEqual(self.run_helper(verify,TEST_SDK='27.0',PLANK_MACOS_CLIENT_TARGET='27.0').returncode,0)

    def test_unprofiled_old_libraries_fail(self):
        (self.base/'dependencies/install').mkdir(parents=True)
        self.assertNotEqual(self.run_helper('plank_macos_client_dependency_profile bootstrap "$2"').returncode,0)


if __name__=='__main__': unittest.main()
