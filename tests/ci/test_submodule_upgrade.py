import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLIENT_KEY = 'submodule.client/moonlight-qt-fork.url'


class SubmoduleUpgradeTests(unittest.TestCase):
    """Exercise the actual bootstrap with real Git and no external services."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_SYSTEM=os.devnull, GIT_CONFIG_NOSYSTEM='1',
                        GIT_ALLOW_PROTOCOL='file', GIT_TERMINAL_PROMPT='0')
        self.upstream = self.repository('upstream')
        self.transport = self.repository('transport')
        self.parent = self.repository('parent')
        self.git(self.parent, 'submodule', 'add', '--name', 'client/moonlight-qt-fork',
                 str(self.upstream), 'apps/client')
        self.git(self.parent, 'submodule', 'add', str(self.transport),
                 'third_party/kyber-kymux')
        self.commit(self.parent, 'Original sources', '.gitmodules', 'apps/client',
                    'third_party/kyber-kymux')
        self.checkout = self.base / 'checkout'
        self.git(self.base, 'clone', '--no-recurse-submodules', str(self.parent), str(self.checkout))
        self.git(self.checkout, 'submodule', 'update', '--init', 'apps/client')
        self.fork = self.base / 'fork'
        self.git(self.base, 'clone', '--no-recurse-submodules', str(self.upstream), str(self.fork))
        (self.fork / 'fork-only.txt').write_text('Fork-only client change\n')
        self.commit(self.fork, 'Fork-only change', 'fork-only.txt')
        self.fork_sha = self.git(self.fork, 'rev-parse', 'HEAD').stdout.strip()
        self.git(self.parent, 'config', '-f', '.gitmodules', CLIENT_KEY, str(self.fork))
        self.git(self.parent, 'add', '.gitmodules')
        self.git(self.parent, 'update-index', '--cacheinfo', f'160000,{self.fork_sha},apps/client')
        self.git(self.parent, 'commit', '-qm', 'Select fork and new gitlink')
        sha = self.git(self.parent, 'rev-parse', 'HEAD').stdout.strip()
        self.git(self.checkout, 'fetch', '--no-recurse-submodules', 'origin')
        self.git(self.checkout, 'checkout', '--no-recurse-submodules', sha)

    def git(self, directory, *args, check=True):
        return subprocess.run([
            'git', '-c', 'user.name=CI fixture', '-c', 'user.email=ci@example.org',
            '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false',
            '-C', str(directory), *args,
        ], env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            check=check, timeout=20)

    def repository(self, name):
        path = self.base / name
        self.git(self.base, 'init', '-q', str(path))
        (path / 'fixture.txt').write_text('Local fixture\n')
        self.commit(path, 'Initial fixture', 'fixture.txt')
        return path

    def commit(self, path, message, *files):
        self.git(path, 'add', *files)
        self.git(path, 'commit', '-qm', message)

    def bootstrap(self, role='linux-client', source=None):
        cargo_root = self.base / 'cargo'
        commands = cargo_root / 'bin'
        commands.mkdir(parents=True, exist_ok=True)
        # Stop at cargo fetch, after source preparation but before any build or download.
        scripts = {
            'rustup': '#!/bin/sh\nexit 1\n',
            'rustc': "#!/bin/sh\necho 'rustc 1.89.0 (29483883e 2025-08-04)'\n",
            'cargo': '#!/bin/sh\nif [ "$1" = --version ]; then\n'
                     "  echo 'cargo 1.89.0 (c24e10642 2025-06-23)'\n  exit 0\nfi\n"
                     'if [ "$1" = fetch ]; then\n  echo sources_ready\n  exit 77\nfi\nexit 1\n',
        }
        for name, text in scripts.items():
            command = commands / name
            command.write_text(text)
            command.chmod(0o755)
        env = dict(self.env, PLANK_SOURCE_ROOT=str(source or self.checkout),
                   PLANK_DEP_ROOT=str(self.base / 'deps'), PLANK_WORK_ROOT=str(self.base / 'work'),
                   PLANK_CARGO_ROOT=str(cargo_root), PLANK_RUSTUP_ROOT=str(self.base / 'rustup'))
        return subprocess.run(['bash', str(ROOT / 'scripts/ci/bootstrap.sh'), role],
                              env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=30)

    def assert_prepared(self, result, source):
        self.assertEqual(result.returncode, 77, result.stdout + result.stderr)
        self.assertIn('sources_ready', result.stdout)
        self.assertEqual(self.git(source, 'config', CLIENT_KEY).stdout.strip(), str(self.fork))
        self.assertEqual(self.git(source / 'apps/client', 'remote', 'get-url', 'origin').stdout.strip(),
                         str(self.fork))
        self.assertEqual(self.git(source / 'apps/client', 'rev-parse', 'HEAD').stdout.strip(), self.fork_sha)

    def test_existing_client_checkout_tracks_changed_url_and_pin(self):
        self.assertEqual(self.git(self.checkout, 'config', CLIENT_KEY).stdout.strip(), str(self.upstream))
        self.assertNotEqual(self.git(self.upstream, 'cat-file', '-e', self.fork_sha, check=False).returncode, 0)
        self.assert_prepared(self.bootstrap(), self.checkout)
        self.assert_prepared(self.bootstrap(), self.checkout)

    def test_fresh_macos_client_checkout_initializes_new_url_and_pin(self):
        fresh = self.base / 'fresh'
        self.git(self.base, 'clone', '--no-recurse-submodules', str(self.parent), str(fresh))
        self.assert_prepared(self.bootstrap('macos-client', fresh), fresh)

    def test_missing_fork_commit_stops_before_dependency_bootstrap(self):
        self.git(self.checkout, 'config', '-f', '.gitmodules', CLIENT_KEY, str(self.upstream))
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(result.returncode, 77)
        self.assertNotIn('sources_ready', result.stdout)

    def test_macos_host_does_not_change_or_update_client(self):
        previous = self.git(self.checkout / 'apps/client', 'rev-parse', 'HEAD').stdout.strip()
        result = self.bootstrap('macos-host')
        self.assertEqual(result.returncode, 77, result.stdout + result.stderr)
        self.assertEqual(self.git(self.checkout, 'config', CLIENT_KEY).stdout.strip(), str(self.upstream))
        self.assertEqual(self.git(self.checkout / 'apps/client', 'rev-parse', 'HEAD').stdout.strip(), previous)


if __name__ == '__main__':
    unittest.main()
