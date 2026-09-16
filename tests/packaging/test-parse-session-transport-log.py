#!/usr/bin/env python3
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARSER = ROOT / 'scripts/test/parse-session-transport-log.py'
MANIFEST = ROOT / 'scripts/test/prepare-p4-evidence-manifest.py'

SAMPLE = """\
info: unrelated line
PlankTransport native transport: video-frames=120 video-bytes=999 video-receive-drops=0 audio-packets=10 audio-bytes=20 audio-receive-drops=0 input-sent=1 data-sent=0 data-received=0 QUIC-lost=2 QUIC-RTT-us=42000 KyProto-drops=0 video-FEC-source-symbols=1000 video-FEC-source-symbols-missing=25 video-FEC-source-symbols-unrecovered=5
"""


class TransportLogParserTests(unittest.TestCase):
    def test_parses_teardown_summary(self):
        with tempfile.NamedTemporaryFile('w', encoding='utf-8', delete=False) as handle:
            handle.write(SAMPLE)
            path = Path(handle.name)
        try:
            payload = json.loads(subprocess.check_output(['python3', str(PARSER), str(path)], text=True))
            self.assertEqual(payload['network_rtt_ms_final'], 42)
            self.assertEqual(payload['pre_fec_loss_percent_final'], 2.5)
            self.assertEqual(payload['post_fec_loss_percent_final'], 0.5)
        finally:
            path.unlink()

    def test_manifest_merge(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'session.log'
            manifest = Path(tmp) / 'manifest.json'
            log.write_text(SAMPLE, encoding='utf-8')
            subprocess.check_call([
                'python3', str(MANIFEST),
                '--branch', 'assignment-refresh',
                '--display-count', '1',
                '--output', str(manifest),
                '--merge-transport-log', str(log),
            ])
            data = json.loads(manifest.read_text(encoding='utf-8'))
            self.assertEqual(data['measurements']['network_rtt_ms_max'], 42)
            self.assertIn('transport_summary', data)


if __name__ == '__main__':
    unittest.main()
