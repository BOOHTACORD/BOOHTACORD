"""Protect the configured active-speaker reporting cadence."""
import unittest
from pathlib import Path

import yaml


class SpeakerActivityConfigTest(unittest.TestCase):
    def test_deployment_updates_speaker_activity_at_150_ms(self):
        root = Path(__file__).resolve().parents[3]
        config = yaml.safe_load((root / 'deploy/livekit/livekit.yaml').read_text())
        self.assertEqual(config.get('audio', {}).get('update_interval'), 150)


if __name__ == '__main__':
    unittest.main()
