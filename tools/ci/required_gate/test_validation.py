import copy
import unittest
from .validation import validate

JOBS = {'changes': 'changes', 'contracts': 'contracts', 'backend': 'backend',
        'web': 'frontend', 'flutter': 'flutter', 'windows': 'windows'}
DIGEST = 'a' * 64


def fixture(selected):
    outputs = {gate: str(gate in selected).lower() for gate in ('backend', 'web', 'flutter', 'windows')}
    outputs.update(contracts='true', map_version='1', map_sha256=DIGEST, uncertain='false')
    needs = {'changes': {'result': 'success', 'outputs': outputs}, 'contracts': {'result': 'success'}}
    needs.update({JOBS[gate]: {'result': 'success' if gate in selected else 'skipped'}
                  for gate in ('backend', 'web', 'flutter', 'windows')})
    return needs


class RequiredGateTests(unittest.TestCase):
    def test_docs_backend_web_and_unknown_success_matrices(self):
        for selected in [[], ['backend'], ['web'], ['backend', 'web', 'flutter', 'windows']]:
            with self.subTest(selected=selected):
                validate(fixture(selected), JOBS, DIGEST)

    def test_required_failure_cancel_skip_missing_never_pass(self):
        for role in JOBS:
            for status in ['failure', 'cancelled', 'skipped', None]:
                needs = fixture(['backend', 'web', 'flutter', 'windows'])
                needs[JOBS[role]]['result'] = status
                with self.subTest(role=role, status=status), self.assertRaises(ValueError):
                    validate(needs, JOBS, DIGEST)
            needs = fixture(['backend'])
            del needs[JOBS[role]]
            with self.assertRaises(ValueError):
                validate(needs, JOBS, DIGEST)

    def test_expected_skip_is_accepted_but_routing_drift_is_rejected(self):
        needs = fixture(['backend'])
        needs['frontend']['result'] = 'success'
        with self.assertRaises(ValueError):
            validate(needs, JOBS, DIGEST)

    def test_partial_invalid_stale_or_uncertain_selection_cannot_pass(self):
        for key, value in [('contracts', 'false'), ('backend', ''), ('web', 'TRUE'),
                           ('map_version', '2'), ('map_sha256', 'b' * 64), ('uncertain', 'true')]:
            needs = fixture(['backend'])
            needs['changes']['outputs'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(needs, JOBS, DIGEST)
        needs = fixture(['backend'])
        needs['changes']['outputs'].pop('windows')
        with self.assertRaises(ValueError):
            validate(needs, JOBS, DIGEST)

    def test_job_names_can_change_only_with_explicit_complete_unique_role_mapping(self):
        needs, jobs = fixture(['backend']), copy.deepcopy(JOBS)
        needs['renamed'] = needs.pop('windows')
        jobs['windows'] = 'renamed'
        validate(needs, jobs, DIGEST)
        jobs['web'] = jobs['windows']
        with self.assertRaises(ValueError):
            validate(needs, jobs, DIGEST)
