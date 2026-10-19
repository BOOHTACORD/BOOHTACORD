"""Real installations start at the older verified source, never downgrade first."""
from copy import deepcopy
import unittest
from .runtime_inputs import ordered


class RuntimeInputTests(unittest.TestCase):
    def test_verified_source_roles_are_preserved_while_initial_runtime_is_older(self):
        proof = {'current': {'head': 'a'*40, 'run': 12},
                 'previous': {'head': 'b'*40, 'run': 11}}
        original = deepcopy(proof)
        calls = []
        result = ordered(proof, lambda older, newer: calls.append((older, newer)) or True)
        self.assertEqual(original, proof)
        self.assertEqual([('b'*40, 'a'*40)], calls)
        self.assertEqual(proof['previous'], result['current'])
        self.assertEqual(proof['current'], result['previous'])

    def test_wrong_missing_identical_or_unrelated_sources_are_refused(self):
        for mode in ('missing', 'same', 'malformed', 'unrelated'):
            proof = {'current': {'head': 'a'*40}, 'previous': {'head': 'b'*40}}
            if mode == 'missing': del proof['previous']
            if mode == 'same': proof['previous']['head'] = 'a'*40
            if mode == 'malformed': proof['current']['head'] = 'master'
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                ordered(proof, lambda *_: mode != 'unrelated')
