"""The shadow control executes the immutable original commands, not a timing proxy."""
import json
import contextlib
import sys
import unittest
from unittest.mock import patch
from tools.ci.native import process
from tools.ci.flutter_setup import vendor_locks
from . import legacy


class LegacyTests(unittest.TestCase):
    def test_reference_is_the_reviewed_monolithic_source(self):
        value = legacy.reference()
        self.assertEqual('f1b190383372e32581790a80fafae3aab33e13e7', value['source_revision'])
        self.assertEqual(11, len(value['operations']))
        for name in value['files']:
            with patch.object(legacy.subprocess, 'check_output', return_value=legacy.frozen(name)) as git:
                self.assertTrue(legacy.original(name))
                git.assert_called_once_with(['git', 'show', value['source_revision'] + ':' + name], cwd=legacy.ROOT)
        with self.assertRaises(ValueError): legacy.original('other.py')

    def test_reference_hash_drift_is_rejected_before_execution(self):
        with patch.object(legacy.subprocess, 'check_output', return_value=b'changed reference source'), self.assertRaises(ValueError):
            legacy.original('tools/ci/native/flutter.py')

    def test_actual_original_dart_call_graph_preserves_every_app_and_vendor_command(self):
        calls = []
        machine = json.dumps({'frameworkVersion': '3.47.7', 'dartSdkVersion': '3.13.5'})
        with patch.object(legacy, 'original', side_effect=legacy.frozen), patch.object(process, 'output', return_value=machine), \
             patch.object(process, 'run', side_effect=lambda *a, **k: calls.append(a)), \
             patch.object(vendor_locks, 'prepare') as prepare:
            completed = legacy.dart()
        self.assertEqual(legacy.reference()['operations'][:8], completed)
        self.assertEqual(8, len(calls)); self.assertEqual(2, prepare.call_count)
        self.assertEqual(3, calls.count(('flutter', 'pub', 'get', '--enforce-lockfile')))
        self.assertEqual(3, calls.count(('flutter', 'test', '--no-pub')))
        self.assertEqual(('flutter', 'analyze', '--no-pub', '--no-fatal-infos'), calls[-1])

    def test_kotlin_control_invokes_the_unchanged_real_two_mode_script(self):
        with patch.object(legacy, 'original', side_effect=legacy.frozen), patch.object(legacy, 'run') as run:
            self.assertEqual(['kotlin-modes'], legacy.kotlin())
        run.assert_called_once_with('bash', 'tools/verify/android_kotlin/verify_android_kotlin_modes.sh')

    def test_native_command_failure_is_not_retried(self):
        with patch.object(legacy, 'original', side_effect=legacy.frozen), patch.object(legacy, 'run', side_effect=RuntimeError('intentional')) as run:
            with self.assertRaises(RuntimeError): legacy.kotlin()
            self.assertEqual(1, run.call_count)

    def test_original_apk_builder_still_resolves_dependencies_and_regenerates_plugins(self):
        from tools.build.android import signing
        calls = []
        def execute(*args, **kwargs):
            calls.append(args)
            if args[:3] == ('flutter', 'build', 'apk'): raise InterruptedError('stop before real build')
        argv = sys.argv
        with patch.object(legacy, 'original', side_effect=legacy.frozen), patch.object(process, 'output', return_value='{"frameworkVersion":"3.47.7"}'), \
             patch.object(process, 'run', side_effect=execute), \
             patch.object(signing, 'provision', return_value=contextlib.nullcontext()):
            with self.assertRaises(InterruptedError): legacy.apk()
        self.assertIs(argv, sys.argv)
        self.assertEqual(('flutter', 'pub', 'get', '--enforce-lockfile'), calls[0])
        self.assertIn('--debug', calls[1]); self.assertNotIn('--no-pub', calls[1])
