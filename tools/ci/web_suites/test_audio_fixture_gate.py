"""Keep audio fixture integrity tests mandatory on the reviewed SFU job."""
import unittest
from . import workflow
from .test_workflow import document


class AudioFixtureGateTests(unittest.TestCase):
    def test_fixture_tests_run_unconditionally_before_sfu_profile(self):
        steps = document()['jobs']['sfu']['steps']
        matches = [step for step in steps if step.get('name') == 'Test audio measurement fixtures']
        self.assertEqual(len(matches), 1)
        step = matches[0]
        self.assertNotIn('if', step)
        self.assertNotIn('continue-on-error', step)
        command = step['run']
        for name in ('test_options.mjs', 'test_verify.mjs', 'test_manifest.mjs',
                     'test_frames.mjs', 'test_runner.mjs'):
            self.assertIn(name, command)
        profile = next(item for item in steps if item.get('name') == 'Run complete reviewed sfu profile')
        self.assertLess(steps.index(step), steps.index(profile))

    def test_validator_rejects_a_skipped_or_ignored_fixture_gate(self):
        for key, value in (('if', 'false'), ('continue-on-error', 'true')):
            workflow_document = document()
            step = next(item for item in workflow_document['jobs']['sfu']['steps']
                        if item.get('name') == 'Test audio measurement fixtures')
            step[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                workflow.validate(workflow_document)
