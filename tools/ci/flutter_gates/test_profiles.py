"""Preserve the native checks while resolving each job's app dependencies once."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from . import profiles


class ProfileTests(unittest.TestCase):
    def exercise(self, profile, failure=None, env=None):
        commands = []

        def execute(*args, **kwargs):
            commands.append((args, kwargs.get('cwd')))
            if failure == args:
                raise RuntimeError('intentional command failure')

        with patch.dict('os.environ', env or {}, clear=True), patch.object(profiles, 'output', return_value=json.dumps({
                'frameworkVersion': '3.47.7', 'dartSdkVersion': '3.13.5 (stable)',
                'frameworkRevision': 'abaf9c523780a608bd46686fd5e53740a07077f8'})), \
             patch.object(profiles, 'run', side_effect=execute), \
             patch.object(profiles, 'prepare') as prepare:
            completed = profiles.execute(profile)
        return commands, completed, prepare

    def test_disposable_pool_uses_four_processes_for_all_app_and_vendor_tests(self):
        env = dict(RUNNER_ENVIRONMENT='self-hosted', RUNNER_OS='Linux',
                   RUNNER_NAME='BOOHTACORD-Hetzner-CI-1-test', BOOHTACORD_EPHEMERAL_GUEST='true')
        commands, completed, _ = self.exercise('dart', env=env)
        tests = [args for args, _ in commands if args[:2] == ('flutter', 'test')]
        self.assertEqual([('flutter', 'test', '--no-pub', '--concurrency=4')] * 3, tests)
        self.assertEqual(list(profiles.OPERATIONS['dart']), completed)

    def test_hosted_and_local_invocations_keep_the_sdk_default(self):
        for env in ({}, dict(RUNNER_ENVIRONMENT='github-hosted', RUNNER_OS='Linux')):
            commands, _, _ = self.exercise('dart', env=env)
            self.assertEqual([('flutter', 'test', '--no-pub')] * 3,
                             [a for a, _ in commands if a[:2] == ('flutter', 'test')])

    def test_dart_keeps_app_both_vendors_recursive_locks_and_analysis(self):
        commands, completed, prepare = self.exercise('dart')
        self.assertEqual(list(profiles.OPERATIONS['dart']), completed)
        app = profiles.ROOT / 'clients/flutter'
        self.assertEqual([
            (('python3', '-m', 'unittest', 'tools.verify.test_flutter_webrtc_public_headers'), None),
            (('flutter', 'pub', 'get', '--enforce-lockfile'), app),
            (('flutter', 'test', '--no-pub'), app),
            (('flutter', 'pub', 'get', '--enforce-lockfile'), app / 'packages/livekit_client'),
            (('flutter', 'test', '--no-pub'), app / 'packages/livekit_client'),
            (('flutter', 'pub', 'get', '--enforce-lockfile'), app / 'packages/flutter_webrtc'),
            (('flutter', 'test', '--no-pub'), app / 'packages/flutter_webrtc'),
            (('flutter', 'analyze', '--no-pub', '--no-fatal-infos'), app),
        ], commands)
        self.assertEqual([(profiles.ROOT, 'livekit_client'), (profiles.ROOT, 'flutter_webrtc')],
                         [call.args for call in prepare.call_args_list])

    def test_android_keeps_both_real_kotlin_modes_and_verified_debug_builder(self):
        commands, completed, prepare = self.exercise('android')
        self.assertEqual(list(profiles.OPERATIONS['android']), completed)
        self.assertEqual([
            (('flutter', 'pub', 'get', '--enforce-lockfile'), profiles.ROOT / 'clients/flutter'),
            (('bash', 'tools/verify/android_kotlin/verify_android_kotlin_modes.sh'), None),
            (('python3', '-m', 'tools.build.android.run', '--debug', '--no-pub'), None),
        ], commands)
        prepare.assert_not_called()

    def test_a_failed_command_is_not_retried_or_reported_as_completed(self):
        with self.assertRaises(RuntimeError):
            self.exercise('dart', ('flutter', 'test', '--no-pub'))

    def test_unknown_profile_and_wrong_sdk_fail_before_commands(self):
        with patch.object(profiles, 'run') as run:
            with self.assertRaises(ValueError): profiles.execute('other')
            with patch.object(profiles, 'output', return_value=json.dumps({
                    'frameworkVersion': '3.47.6', 'dartSdkVersion': '3.13.5'})):
                with self.assertRaises(RuntimeError): profiles.execute('dart')
            run.assert_not_called()

    def test_same_flutter_label_with_another_framework_revision_is_rejected(self):
        with patch.object(profiles, 'run') as run, patch.object(profiles, 'output', return_value=json.dumps({
                'frameworkVersion': '3.47.7', 'dartSdkVersion': '3.13.5', 'frameworkRevision': 'b' * 40})):
            with self.assertRaises(ValueError): profiles.execute('dart')
            run.assert_not_called()

    def test_existing_kotlin_script_keeps_both_modes_and_compatibility_warning_guard(self):
        script = (profiles.ROOT / 'tools/verify/android_kotlin/verify_android_kotlin_modes.sh').read_text()
        self.assertIn('set -euo pipefail', script)
        self.assertIn('flutter build apk --debug --no-pub', script)
        self.assertIn('./gradlew :app:assembleDebug -Pandroid.builtInKotlin=true --no-daemon', script)
        self.assertIn('Unexpected Flutter KGP compatibility warning.', script)
