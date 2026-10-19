"""One master producer owns contracts and only the selected server release work."""
import copy
import unittest
from . import validation

DIGEST = 'a' * 64


def selected(server=True):
    return {'contracts': 'true', 'server_release_impact': str(server).lower(),
            'map_version': '1', 'map_sha256': DIGEST, 'uncertain': 'false',
            'flutter': 'true', 'windows': 'false'}


def server_needs(release=True):
    return {'changes': {'result': 'success', 'outputs': selected(release)},
            'contracts': {'result': 'success'},
            **{name: {'result': 'success' if release else 'skipped'} for name in ('backend', 'web')}}


class ServerQualityTests(unittest.TestCase):
    def test_relevant_master_requires_all_three_successful_gates(self):
        self.assertEqual({'status': 'PASS', 'server_release_impact': True}, validation.server(server_needs(), DIGEST))

    def test_non_release_still_requires_contracts_but_skips_both_heavy_gates(self):
        needs = server_needs(False)
        self.assertEqual({'status': 'PASS', 'server_release_impact': False}, validation.server(needs, DIGEST))
        for role, state in [('contracts', 'skipped'), ('web', 'success'), ('backend', 'success')]:
            changed = copy.deepcopy(needs); changed[role]['result'] = state
            with self.subTest(role=role), self.assertRaises(ValueError): validation.server(changed, DIGEST)

    def test_missing_failed_cancelled_timed_out_or_partial_gate_cannot_build(self):
        for role in ('changes', 'contracts', 'backend', 'web'):
            for result in ('failure', 'cancelled', 'timed_out', 'skipped', None):
                needs = server_needs(); needs[role]['result'] = result
                with self.subTest(role=role, result=result), self.assertRaises(ValueError): validation.server(needs, DIGEST)
            needs = server_needs(); needs.pop(role)
            with self.assertRaises(ValueError): validation.server(needs, DIGEST)

    def test_wrong_map_missing_impact_or_uncertain_skip_is_not_an_explicit_no_release(self):
        for field, wrong in [('map_version', '2'), ('map_sha256', 'b' * 64), ('contracts', 'false'),
                             ('server_release_impact', None), ('uncertain', None)]:
            needs = server_needs(); needs['changes']['outputs'][field] = wrong
            with self.subTest(field=field), self.assertRaises(ValueError): validation.server(needs, DIGEST)
        needs = server_needs(False); needs['changes']['outputs']['uncertain'] = 'true'
        with self.assertRaises(ValueError): validation.server(needs, DIGEST)


class NativeQualityTests(unittest.TestCase):
    def fixture(self):
        return {'changes': {'result': 'success', 'outputs': selected()},
                'flutter': {'result': 'success'}, 'windows': {'result': 'skipped'}}

    def test_native_master_does_not_run_or_wait_for_server_gates(self):
        self.assertEqual({'status': 'PASS', 'flutter': True, 'windows': False}, validation.native(self.fixture(), DIGEST))

    def test_missing_failed_or_unexpectedly_skipped_native_jobs_fail(self):
        for role, state in [('flutter', 'skipped'), ('flutter', 'failure'), ('windows', 'success'), ('changes', 'cancelled')]:
            needs = self.fixture(); needs[role]['result'] = state
            with self.subTest(role=role, state=state), self.assertRaises(ValueError): validation.native(needs, DIGEST)
        needs = self.fixture(); needs.pop('windows')
        with self.assertRaises(ValueError): validation.native(needs, DIGEST)

    def test_unknown_diff_cannot_skip_windows_and_extra_server_dependencies_are_rejected(self):
        needs = self.fixture(); needs['changes']['outputs']['uncertain'] = 'true'
        with self.assertRaises(ValueError): validation.native(needs, DIGEST)
        needs = self.fixture(); needs['contracts'] = {'result': 'success'}
        with self.assertRaises(ValueError): validation.native(needs, DIGEST)
