import random
import unittest

from .trials import paired_trials, listener_sheet


class BlindQualityTrialsTest(unittest.TestCase):
    def test_each_pair_is_balanced_and_each_listener_gets_every_condition(self):
        scenarios = ['clean', 'quiet', 'keyboard']
        candidates = ['v02', 'dfn3']
        assignments = paired_trials(scenarios, candidates, 10, random.Random(47))
        self.assertEqual(len(assignments), 60)
        self.assertEqual(len({trial['trial'] for trial in assignments}), 60)
        for listener in range(1, 11):
            self.assertEqual(len(listener_sheet(assignments, listener)), 6)
        for scenario in scenarios:
            for candidate in candidates:
                trials = [t for t in assignments if t['scenario'] == scenario and t['candidate'] == candidate]
                self.assertEqual(len(trials), 10)
                self.assertEqual(sum(t['first'] == 'v01' for t in trials), 5)
                self.assertEqual({t['listener'] for t in trials}, set(range(1, 11)))
        self.assertEqual(assignments, paired_trials(scenarios, candidates, 10, random.Random(47)))

    def test_listener_sheet_contains_no_model_or_scenario_identity(self):
        assignments = paired_trials(['quiet'], ['v02'], 10, random.Random(1))
        self.assertEqual(set(listener_sheet(assignments, 1)[0]), {'trial', 'preferred', 'speech_defect'})

    def test_rejects_duplicate_or_unbalanced_inputs(self):
        for scenarios, candidates, count in [([], ['v02'], 10), (['a', 'a'], ['v02'], 10),
                                              (['a'], ['v01'], 10), (['a'], ['v02'], 9),
                                              (['a'], ['v02'], 11)]:
            with self.subTest(scenarios=scenarios, count=count), self.assertRaises(ValueError):
                paired_trials(scenarios, candidates, count, random.Random(1))
