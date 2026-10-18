import copy
import unittest
from .routing import decision
from . import test_provenance


class ProducerRoutingTests(unittest.TestCase):
    def setUp(self):
        fixture = test_provenance.ArtifactProvenanceTests()
        fixture.setUp()
        self.run = {**fixture.run, 'id': 123}
        self.jobs = {'total_count': 5, 'jobs': [
            {'id': i, 'run_id': 123, 'name': name, 'status': 'completed', 'conclusion': 'success'}
            for i, name in enumerate(['changes', 'backend / backend', 'web / frontend',
                                       'contracts / contracts', 'bundle'], 1)]}

    def test_successful_bundle_keeps_existing_provenance_guards(self):
        result = decision(self.run, self.jobs, 'owner/repo')
        self.assertTrue(result['has_bundle'])
        self.assertEqual(result['revision'], 'a' * 40)
        with self.assertRaises(ValueError):
            decision({**self.run, 'head_repository': {'full_name': 'fork/repo'}}, self.jobs, 'owner/repo')

    def test_explicit_nonimpact_route_is_only_valid_no_bundle_case(self):
        for job in self.jobs['jobs'][1:]:
            job['conclusion'] = 'skipped'
            job['name'] = job['name'].split(' / ')[0]
        self.assertFalse(decision(self.run, self.jobs, 'owner/repo')['has_bundle'])
        self.jobs['jobs'][0]['conclusion'] = 'failure'
        with self.assertRaises(ValueError):
            decision(self.run, self.jobs, 'owner/repo')

    def test_missing_failed_cancelled_duplicate_foreign_or_incomplete_jobs_fail_closed(self):
        for field, value in [('conclusion', 'cancelled'), ('conclusion', 'failure'),
                             ('status', 'in_progress'), ('run_id', 999)]:
            broken = copy.deepcopy(self.jobs)
            broken['jobs'][-1][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                decision(self.run, broken, 'owner/repo')
        for broken in [ {'total_count': 6, 'jobs': self.jobs['jobs']},
                        {'total_count': 4, 'jobs': self.jobs['jobs'][:-1]},
                        {'total_count': 6, 'jobs': self.jobs['jobs'] + [self.jobs['jobs'][-1]]} ]:
            with self.assertRaises(ValueError):
                decision(self.run, broken, 'owner/repo')

    def test_legacy_successful_build_without_selector_still_deploys(self):
        self.jobs['jobs'].pop(0)
        self.jobs['total_count'] = 4
        self.assertTrue(decision(self.run, self.jobs, 'owner/repo')['has_bundle'])
        self.jobs['jobs'][-1]['conclusion'] = 'skipped'
        with self.assertRaises(ValueError):
            decision(self.run, self.jobs, 'owner/repo')

    def test_running_gates_cannot_be_replaced_by_bare_caller_success(self):
        self.jobs['jobs'][1]['name'] = 'backend'
        with self.assertRaises(ValueError): decision(self.run, self.jobs, 'owner/repo')

    def test_internal_skips_are_not_proven_wrapper_skips(self):
        for job in self.jobs['jobs'][1:]: job['conclusion'] = 'skipped'
        with self.assertRaises(ValueError): decision(self.run, self.jobs, 'owner/repo')

    def test_both_caller_and_qualified_gate_aliases_are_ambiguous(self):
        for skipped in (False, True):
            broken = copy.deepcopy(self.jobs)
            if skipped:
                for job in broken['jobs'][1:]:
                    job['conclusion'] = 'skipped'
                    job['name'] = job['name'].split(' / ')[0]
            extra = copy.deepcopy(broken['jobs'][1])
            extra.update(id=99, name='backend / backend' if skipped else 'backend')
            broken['jobs'].append(extra);broken['total_count'] += 1
            with self.subTest(skipped=skipped), self.assertRaises(ValueError):
                decision(self.run, broken, 'owner/repo')
