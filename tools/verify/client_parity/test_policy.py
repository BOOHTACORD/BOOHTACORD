import copy
import unittest
from .policy import validate

def scenario():
    return {'id': 'auth.session', 'expected': 'Expired session clears private state; outage preserves it.', 'issue': 518,
            'status': 'PARITY', 'source': 'current checkout', 'shipped': 'NOT_VERIFIED',
            'platforms': {p: {'entrypoint': 'AGENTS.md', 'tests': ['AGENTS.md'], 'runtime': 'NOT_VERIFIED', 'conditions': 'foreground'} for p in ['web', 'ios', 'android']}}

class ParityPolicyTest(unittest.TestCase):
    def test_implementation_is_not_three_runtime_passes(self):
        validate({'auth': {'parity': [scenario()], 'parity_review': {'issue': 518, 'decisions': {p: 'implementation_and_regression' for p in ['web', 'ios', 'android']}}}})

    def test_duplicate_id_missing_platform_and_unexplained_gap_fail(self):
        for mutation in ['duplicate', 'platform', 'gap', 'fake-pass']:
            row = scenario()
            if mutation == 'platform': del row['platforms']['ios']
            if mutation == 'gap': row['status'] = 'GAP'
            if mutation == 'fake-pass': row['platforms']['ios']['runtime'] = 'PASS'
            rows = [row, copy.deepcopy(row)] if mutation == 'duplicate' else [row]
            with self.assertRaises(ValueError):
                validate({'auth': {'parity': rows, 'parity_review': {'issue': 518, 'decisions': {p: 'implementation_and_regression' for p in ['web', 'ios', 'android']}}}})
