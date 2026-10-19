"""Current workflows publish one verified package, retaining receipts and native proof."""
import unittest
from pathlib import Path
import yaml
from tools.verify.action_pins.policy import normalized
from .retention import CAPTURE_EXPRESSION

ROOT = Path(__file__).resolve().parents[3]


def workflow(name):
    return yaml.load(normalized((ROOT / '.github/workflows' / name).read_text()), Loader=yaml.BaseLoader)


class ArtifactWorkflowAdoptionTests(unittest.TestCase):
    def test_browser_and_dart_upload_only_verified_packages_with_bounded_retention(self):
        for name, key, component, profile in [('ci-frontend.yaml', 'browser', 'web', '${{ matrix.profile }}'),
                                              ('ci-flutter.yaml', 'dart', 'flutter', 'dart')]:
            job = workflow(name)['jobs'][key]
            output = '.out/ci/capture-packages/' + component + '-' + profile + '/'
            uploads = [s for s in job['steps'] if s.get('uses') == 'actions/upload-artifact@v4'
                       and s['with']['path'] == output]
            with self.subTest(workflow=name):
                self.assertEqual(1, len(uploads))
                self.assertEqual('always()', uploads[0]['if'])
                self.assertEqual('error', uploads[0]['with']['if-no-files-found'])
                self.assertEqual(CAPTURE_EXPRESSION, uploads[0]['with']['retention-days'])
                self.assertFalse(any(s.get('with', {}).get('path') in ('.out/visual/flutter/**', '.out/visual/flutter/R14-navigation-top.png')
                                     for s in job['steps']))

    def test_windows_artifacts_have_finite_full_execution_identity_and_durable_retention(self):
        document = workflow('flutter-windows.yaml')
        names = {s['with']['name'] for s in document['jobs']['windows']['steps']
                 if s.get('uses') == 'actions/upload-artifact@v4'}
        suffix = '-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
        self.assertEqual({prefix + suffix for prefix in ('desktop-recovery-windows', 'BOOHTACORD-windows-x64',
                                                         'BOOHTACORD-windows-installer-x64', 'screen-setup-windows')}, names)

    def test_receipts_and_native_packages_remain_mandatory_thirty_day_uploads(self):
        for name in ('ci-flutter.yaml', 'ci-frontend.yaml'):
            for job in workflow(name)['jobs'].values():
                for step in job.get('steps', []):
                    if step.get('uses') != 'actions/upload-artifact@v4': continue
                    config = step['with']
                    if config['name'].startswith(('web-part-', 'flutter-part-', 'check-', 'boohtacord-android-debug-apk-')):
                        self.assertEqual(('error', '30'), (config['if-no-files-found'], config['retention-days']))

    def test_policy_rejects_raw_fallback_missing_freshness_optional_packaging_or_wrong_status(self):
        from . import workflows
        from copy import deepcopy
        original = workflow('ci-frontend.yaml')['jobs']['browser']
        for change in ('freshness', 'finish-if', 'ignored', 'status', 'raw-upload', 'retention', 'identity'):
            value = deepcopy(original)
            begin = next(s for s in value['steps'] if 'artifact_policy.run begin' in s.get('run', ''))
            finish = next(s for s in value['steps'] if 'artifact_policy.run finish' in s.get('run', ''))
            upload = next(s for s in value['steps'] if s.get('with', {}).get('path', '').startswith('.out/ci/capture-packages/'))
            if change == 'freshness': value['steps'].remove(begin)
            if change == 'finish-if': finish['if'] = 'success()'
            if change == 'ignored': finish['continue-on-error'] = 'true'
            if change == 'status': finish['env']['CAPTURE_UPSTREAM_STATUS'] = 'success'
            if change == 'raw-upload': value['steps'].append({**deepcopy(upload), 'with': {**upload['with'], 'path': '.out/**'}})
            if change == 'retention': upload['with']['retention-days'] = '1'
            if change == 'identity': upload['with']['name'] = 'web-visual-latest'
            with self.subTest(change=change), self.assertRaises(ValueError):
                workflows.capture_job(value, 'web', '${{ matrix.profile }}', 'python3 -m tools.ci.web_suites.run --profile "$WEB_PROFILE"')
