import copy
from pathlib import Path
import unittest
import yaml
from tools.verify.action_pins.policy import ROOT, normalized
from tools.verify.action_pins.trust import check
from .routing import LINUX, META, measured_linux, measurement_pool, isolated_linux


class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.docs = {p.name: yaml.load(normalized(p.read_text()), Loader=yaml.BaseLoader)
                     for p in (ROOT / '.github/workflows').glob('*.yaml')}

    def test_every_general_linux_job_uses_ephemeral_pool(self):
        count = 0
        for name, doc in self.docs.items():
            for ident, job in doc['jobs'].items():
                runner = job.get('runs-on')
                with self.subTest(workflow=name, job=ident):
                    self.assertNotIn(runner if isinstance(runner, str) else '', ('ubuntu-24.04', 'ubuntu-latest'))
                if runner == LINUX or runner == META: count += 1
        self.assertGreater(count, 40)
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

    def test_persistent_or_unmarked_self_hosted_runtime_cannot_publish(self):
        env = dict(RUNNER_ENVIRONMENT='self-hosted', RUNNER_OS='Linux',
                   BOOHTACORD_EPHEMERAL_GUEST='true', RUNNER_NAME='BOOHTACORD-Hetzner-CI-1-unique')
        self.assertTrue(isolated_linux(env))
        self.assertFalse(isolated_linux(dict(env, RUNNER_NAME='BOOHTACORD-Hetzner-Web')))
        env.pop('BOOHTACORD_EPHEMERAL_GUEST')
        self.assertFalse(isolated_linux(env))
