import copy
import unittest
import yaml
from tools.verify.action_pins.policy import ROOT, normalized
from tools.verify.action_pins.trust import check
from .routing import GITHUB_LINUX, LINUX, META, measured_linux, measurement_pool, isolated_linux


class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.docs = {p.name: yaml.load(normalized(p.read_text()), Loader=yaml.BaseLoader)
                     for p in (ROOT / '.github/workflows').glob('*.yaml')}

    def test_default_ci_jobs_use_github_hosted_linux(self):
        expected = {
            'ci.yaml': {'changes', 'ci-required'},
            'ci-contracts.yaml': {'contracts'},
            'ci-backend.yaml': {'static', 'database', 'load', 'backend'},
            'ci-frontend.yaml': {'fast', 'browser', 'sfu', 'frontend'},
            'ci-flutter.yaml': {'dart', 'android', 'android-kotlin', 'flutter'},
            'ci-actual-acceptance.yaml': {'runtime', 'actual-acceptance'},
            'ci-observability.yaml': {'triage'},
            'flutter-windows.yaml': {'windows'},
        }
        for name, identities in expected.items():
            jobs = self.docs[name]['jobs']
            with self.subTest(workflow=name):
                self.assertTrue(identities <= set(jobs))
                for identity in identities:
                    with self.subTest(job=identity):
                        self.assertEqual(GITHUB_LINUX, jobs[identity]['runs-on'])
        count = 0
        for name, doc in self.docs.items():
            for job in doc['jobs'].values():
                runner = job.get('runs-on')
                if runner == GITHUB_LINUX:
                    count += 1
        self.assertGreater(count, 30)
        check(self.docs)

    def test_general_pr_cannot_target_the_signing_builder(self):
        doc = copy.deepcopy(self.docs)
        doc['ci.yaml']['jobs']['changes']['runs-on'] = ['self-hosted', 'linux', 'x64', 'boohtacord-builder']
        with self.assertRaises(ValueError): check(doc)

    def test_timing_metadata_is_bound_to_the_measured_pool(self):
        self.assertTrue(measured_linux(dict(labels=LINUX, runner_name='BOOHTACORD-Hetzner-CI-1-unique')))
        self.assertFalse(measured_linux(dict(labels=['ubuntu-24.04'], runner_name='GitHub Actions 1')))
        self.assertFalse(measured_linux(dict(labels=LINUX, runner_name='BOOHTACORD-Hetzner-Web')))

    def test_shadow_results_cannot_mix_hosted_and_self_hosted_machines(self):
        hosted = dict(labels=['ubuntu-24.04'], runner_group_name='GitHub Actions')
        pool = dict(labels=LINUX, runner_name='BOOHTACORD-Hetzner-CI-1-unique')
        self.assertEqual('boohtacord-ci-ephemeral', measurement_pool([pool, pool]))
        with self.assertRaises(ValueError): measurement_pool([hosted, pool])

    def test_only_github_hosted_linux_is_an_isolated_linux_runtime(self):
        env = dict(RUNNER_ENVIRONMENT='github-hosted', RUNNER_OS='Linux')
        self.assertTrue(isolated_linux(env))
        self.assertFalse(isolated_linux(dict(env, RUNNER_OS='Windows')))
        self.assertFalse(isolated_linux(dict(env, RUNNER_ENVIRONMENT='self-hosted')))

    def test_hosted_proof_checks_runner_environment_without_pool_specific_limits(self):
        steps = self.docs['self-hosted-proof.yaml']['jobs']['probe']['steps']
        run = next(step['run'] for step in steps if step.get('name') ==
                   'Verify GitHub-hosted Linux runner and isolated workspace')
        self.assertIn('RUNNER_ENVIRONMENT', run)
        self.assertIn('github-hosted', run)
        self.assertIn('GITHUB_WORKSPACE', run)
        self.assertNotIn('BOOHTACORD_EPHEMERAL_GUEST', run)
        self.assertNotIn('/etc/needrestart', run)
