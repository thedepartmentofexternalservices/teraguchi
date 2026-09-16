#!/usr/bin/env python3
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/test/prepare-p4-evidence-manifest.py"


class P4EvidenceManifestTest(unittest.TestCase):
    def test_prepares_incomplete_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "manifest.json"
            subprocess.check_call([
                "python3", str(SCRIPT),
                "--branch", "assignment-refresh",
                "--display-count", "1",
                "--output", str(output),
            ])
            manifest = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "incomplete")
            self.assertEqual(manifest["run"]["display_count"], 1)
            self.assertTrue(manifest["candidate"]["root_commit"])
            self.assertIsNone(manifest["candidate"]["package_sha256"])
            self.assertEqual(manifest["gates"]["P4_direct_path_load"], "not-run")

    def test_rejects_existing_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "manifest.json"
            output.write_text("{}\n", encoding="utf-8")
            with self.assertRaises(subprocess.CalledProcessError):
                subprocess.check_call([
                    "python3", str(SCRIPT),
                    "--branch", "main",
                    "--display-count", "2",
                    "--output", str(output),
                ])


if __name__ == "__main__":
    unittest.main()
