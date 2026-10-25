"""The Flutter aggregate cannot hide a required platform or artifact failure."""
import copy
from pathlib import Path
import unittest
import yaml
from tools.verify.action_pins.policy import normalized
from tools.ci.runner_pool.routing import GITHUB_LINUX
from . import workflow

ROOT = Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def test_split_android_jobs_keep_pool_sdk_and_independent_finite_budgets(self):
        jobs = self.document()['jobs']
        for profile in ('android-kotlin', 'android'):
            with self.subTest(profile=profile):
                job = jobs[profile]
                self.assertEqual(GITHUB_LINUX, job['runs-on'])
                self.assertEqual('30', job['timeout-minutes'])
                java = next(step for step in job['steps'] if step.get('uses', '').startswith('actions/setup-java@'))
                self.assertEqual('17.0.20+101', java['with']['java-version'])
                self.assertNotIn('needs', job)

    def test_shared_host_android_budget_is_finite_without_optional_commands(self):
        workflow.validate(self.document())
        for profile in ('android', 'android-kotlin'):
            for minutes in ('0', '360', ''):
                value = self.document()
                value['jobs'][profile]['timeout-minutes'] = minutes
                with self.subTest(profile=profile, minutes=minutes), self.assertRaises(ValueError):
                    workflow.validate(value)

    def document(self):
        return yaml.load(normalized((ROOT / '.github/workflows/ci-flutter.yaml').read_text()), Loader=yaml.BaseLoader)

    def test_current_workflow_preserves_parallel_native_gates_and_stable_status(self):
        workflow.validate(self.document())

    def test_conditional_ignored_or_missing_native_commands_are_rejected(self):
        for profile in ('dart', 'android', 'android-kotlin', 'macos'):
            for field in ('if', 'continue-on-error', 'remove-command', 'job-if', 'serial-dependency'):
                document = self.document(); job = document['jobs'][profile]
                step = next(s for s in job['steps'] if s.get('run') == 'python3 -m tools.ci.flutter_gates.run ' + profile)
                if field == 'remove-command': job['steps'].remove(step)
                elif field == 'job-if': job['if'] = 'false'
                elif field == 'serial-dependency': job['needs'] = ['dart']
                else: step[field] = 'true'
                with self.subTest(profile=profile, field=field), self.assertRaises(ValueError):
                    workflow.validate(document)

    def test_profile_failures_uploads_or_proofs_cannot_be_optional(self):
        for profile in ('dart', 'android', 'android-kotlin', 'macos'):
            for path in ('proof', 'artifacts'):
                document = self.document(); job = document['jobs'][profile]
                upload = next(s for s in job['steps'] if s.get('uses') == 'actions/upload-artifact@v4'
                              and (('.out/ci/flutter-parts/' in s['with']['path']) == (path == 'proof')))
                upload['with']['if-no-files-found'] = 'ignore'
                with self.subTest(profile=profile, path=path), self.assertRaises(ValueError):
                    workflow.validate(document)

    def test_stable_aggregate_always_requires_both_exact_current_profile_parts(self):
        for mutation in ('needs', 'if', 'download', 'validator'):
            document = self.document(); job = document['jobs']['flutter']
            if mutation == 'needs': job['needs'] = ['dart']
            elif mutation == 'if': job['if'] = 'success()'
            elif mutation == 'download':
                step = next(s for s in job['steps'] if s.get('uses') == 'actions/download-artifact@v4')
                step['with']['pattern'] = 'flutter-part-*'
            else:
                step = next(s for s in job['steps'] if s.get('run') == 'python3 -m tools.ci.flutter_gates.aggregate')
                step['env']['FLUTTER_NEEDS'] = '{}'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(document)
