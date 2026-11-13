import unittest
from unittest.mock import patch

from tools.audio.speech_metrics.batch import summarize


class BatchTest(unittest.TestCase):
    def test_groups_results_without_emitting_paths(self):
        manifest = {'pairs': [
            {'engine': 'a', 'reference': 'private', 'referenceSha256': 'a' * 64,
             'candidate': 'private2', 'candidateSha256': 'b' * 64, 'lagSamples': 10},
            {'engine': 'a', 'reference': 'private', 'referenceSha256': 'a' * 64,
             'candidate': 'private3', 'candidateSha256': 'c' * 64, 'lagSamples': 10},
        ]}
        with patch('tools.audio.speech_metrics.batch.read_checked', return_value=object()), \
             patch('tools.audio.speech_metrics.batch.score_pair', side_effect=[{'stoi': .4, 'estoi': .2}, {'stoi': .8, 'estoi': .6}]):
            result = summarize(manifest)
        self.assertEqual(result['engines']['a']['stoi'], [0.4, 0.6, 0.8])
        self.assertNotIn('private', str(result))
        self.assertEqual(result['engines']['a']['count'], 2)
        self.assertEqual(result['engines']['a']['lagSamples'], 10)

    def test_rejects_empty_and_bad_manifest(self):
        for manifest in ({}, {'pairs': []}, {'pairs': [{'engine': 'wrong label'}]}):
            with self.assertRaises(ValueError):
                summarize(manifest)


if __name__ == '__main__':
    unittest.main()
