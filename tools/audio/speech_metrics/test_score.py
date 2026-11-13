import unittest
from unittest.mock import patch

import numpy as np

from tools.audio.speech_metrics.score import score_pair, verified_versions


class ScoreTest(unittest.TestCase):
    def setUp(self):
        random = np.random.default_rng(687)
        time = np.arange(96000) / 48000
        self.signal = (random.normal(size=time.size) * (0.2 + 0.1 * np.sin(2 * np.pi * 3 * time)))

    def test_identical_signal_with_known_leading_delay(self):
        candidate = np.concatenate((np.zeros(480), self.signal, np.zeros(100)))
        result = score_pair(self.signal, candidate, 480)
        self.assertAlmostEqual(result['stoi'], 1.0, places=5)
        self.assertAlmostEqual(result['estoi'], 1.0, places=5)

    def test_rejects_short_silent_nonfinite_and_invalid_alignment(self):
        with self.assertRaises(ValueError):
            score_pair(np.zeros(47999), np.zeros(96000), 0)
        with self.assertRaises(ValueError):
            score_pair(np.zeros(48000), np.zeros(48000), 0)
        with self.assertRaises(ValueError):
            score_pair(self.signal, self.signal, -1)
        with self.assertRaises(ValueError):
            score_pair(self.signal, self.signal, 1)
        bad = self.signal.copy(); bad[0] = np.nan
        with self.assertRaises(ValueError):
            score_pair(bad, self.signal, 0)

    def test_rejects_unpinned_metric_versions(self):
        with patch('tools.audio.speech_metrics.score.importlib.metadata.version', return_value='0.0'):
            with self.assertRaises(ValueError):
                verified_versions()


if __name__ == '__main__':
    unittest.main()
