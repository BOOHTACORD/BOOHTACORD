import random
import unittest

from .score import summarize
from .trials import paired_trials


class BlindQualityScoreTest(unittest.TestCase):
    def setUp(self):
        self.plan = paired_trials(['quiet', 'keyboard'], ['v02', 'dfn3'], 10, random.Random(9))
        self.votes = [{'trial': trial['trial'], 'preferred': 'A' if trial['first'] == trial['candidate'] else 'B',
                       'speech_defect': 'no'} for trial in self.plan]

    def test_counts_preferences_without_claiming_acceptance(self):
        summary = summarize(self.plan, self.votes)
        self.assertEqual(summary['acceptance'], 'NOT_ASSESSED')
        self.assertEqual(summary['models']['v02']['new'], 20)
        self.assertEqual(summary['models']['dfn3']['new'], 20)
        self.assertEqual(summary['models']['v02']['total'], 20)
        self.assertEqual(summary['conditions']['v02']['quiet']['new'], 10)

    def test_incomplete_duplicate_or_invalid_responses_fail_closed(self):
        for votes in (self.votes[:-1], self.votes + [self.votes[0]],
                      [{**self.votes[0], 'preferred': 'yes'}, *self.votes[1:]]):
            with self.subTest(size=len(votes)), self.assertRaises(ValueError):
                summarize(self.plan, votes)

    def test_rejects_an_unbalanced_or_missing_listener(self):
        plan = [trial for trial in self.plan if trial['listener'] != 10]
        votes = [vote for vote in self.votes if vote['trial'] in {trial['trial'] for trial in plan}]
        with self.assertRaises(ValueError):
            summarize(plan, votes)

    def test_rejects_a_missing_model_scenario_pair(self):
        plan = [trial for trial in self.plan if (trial['scenario'], trial['candidate']) != ('quiet', 'dfn3')]
        ids = {trial['trial'] for trial in plan}
        with self.assertRaises(ValueError):
            summarize(plan, [vote for vote in self.votes if vote['trial'] in ids])
