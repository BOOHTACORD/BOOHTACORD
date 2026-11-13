"""Keep audio fixture integrity tests mandatory on the reviewed SFU job."""
import unittest
from . import workflow
from .test_workflow import document


class AudioFixtureGateTests(unittest.TestCase):
    def test_firefox_audio_runs_unconditionally_after_profile(self):
        steps = document()['jobs']['sfu']['steps']
        audio = [step for step in steps if step.get('run') == 'python3 -m tools.ci.web_suites.firefox_audio']
        self.assertEqual(len(audio), 1)
        profile = next(step for step in steps if step.get('name') == 'Run complete reviewed sfu profile')
        self.assertGreater(steps.index(audio[0]), steps.index(profile))
        for key, value in (('if', 'false'), ('continue-on-error', 'true')):
            changed = document()
            next(s for s in changed['jobs']['sfu']['steps']
                 if s.get('run') == 'python3 -m tools.ci.web_suites.firefox_audio')[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): workflow.validate(changed)

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
        source = next(item for item in steps if item.get('name') == 'Test audio research checks')
        self.assertNotIn('if', source)
        self.assertNotIn('continue-on-error', source)
        self.assertEqual(source['run'], workflow.AUDIO_RESEARCH)
        self.assertLess(steps.index(source), steps.index(profile))

    def test_validator_rejects_a_skipped_or_ignored_fixture_gate(self):
        for name in ('Test audio measurement fixtures', 'Test audio research checks'):
            for key, value in (('if', 'false'), ('continue-on-error', 'true')):
                workflow_document = document()
                step = next(item for item in workflow_document['jobs']['sfu']['steps']
                            if item.get('name') == name)
                step[key] = value
                with self.subTest(name=name, key=key), self.assertRaises(ValueError):
                    workflow.validate(workflow_document)
