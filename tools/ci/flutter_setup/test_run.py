"""Fail closed before executing an altered installer or accepting another SDK."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import run


class FlutterInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name).resolve()
        self.installer = self.directory / 'installer'; self.installer.mkdir()
        self.sdk = self.directory / 'sdk'; (self.sdk / 'bin').mkdir(parents=True)
        (self.sdk / 'bin/flutter').write_text('fixture')
        self.value = {'installer_revision': 'a' * 40, 'version': '3.47.7',
                      'architecture': 'x64', 'cache_path': str(self.directory),
                      'pub_cache': str(self.directory / 'private-pub'), 'flutter_root': str(self.sdk),
                      'framework_revision': 'b' * 40, 'dart_version': '3.13.5'}
        self.machine = {'frameworkVersion': '3.47.7', 'frameworkRevision': 'b' * 40,
                        'dartSdkVersion': '3.13.5 (stable)'}

    def test_only_canonical_git_blob_is_executed_with_private_pub_cache(self):
        blob = b'#!/bin/bash\n# canonical LF script\n'
        def invoked(args, **kwargs):
            if '--machine' in args:
                return type('Result', (), {'stdout': json.dumps(self.machine)})()
        with patch.object(run, 'INSTALLER', self.installer), patch.object(run.platform, 'system', return_value='Linux'), \
                patch.object(run.subprocess, 'check_output', side_effect=['a' * 40, blob]) as read, \
                patch.object(run.subprocess, 'run', side_effect=invoked) as execute:
            run.installed(self.value)
        read.assert_any_call(['git', '-C', str(self.installer), 'show', 'a' * 40 + ':setup.sh'])
        script = next(c for c in execute.call_args_list if c.args[0][0] == 'bash')
        self.assertEqual(script.kwargs['input'], blob)
        self.assertEqual(script.kwargs['env']['PUB_CACHE'], self.value['pub_cache'])
        self.assertIn('https://github.com/flutter/flutter.git', script.args[0])

    def test_wrong_installer_revision_fails_before_any_script_runs(self):
        with patch.object(run, 'INSTALLER', self.installer), \
                patch.object(run.subprocess, 'check_output', return_value='c' * 40), \
                patch.object(run.subprocess, 'run') as execute, self.assertRaises(ValueError):
            run.installed(self.value)
        execute.assert_not_called()

    def test_runner_identity_mismatch_is_not_a_cache_fallback(self):
        with patch.dict(run.os.environ, {'RUNNER_OS': 'Windows', 'RUNNER_ARCH': 'X64'}), \
                patch.object(run.platform, 'system', return_value='Linux'), \
                patch.object(run.platform, 'machine', return_value='x86_64'), self.assertRaises(ValueError):
            run.context()
