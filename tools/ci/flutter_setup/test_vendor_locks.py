"""Standalone vendor regressions use reviewed locks without changing the app lock."""
import json
from pathlib import Path
import tempfile
import unittest
from . import vendor_locks

ROOT = Path(__file__).resolve().parents[3]


class VendorLockTests(unittest.TestCase):
    def test_actual_lock_inventory_has_only_public_packages_and_known_local_fork(self):
        for name in ('livekit_client', 'flutter_webrtc'):
            vendor_locks.validate(ROOT, name)
        vendor_locks.audit_public(ROOT)

    def test_missing_changed_or_indirect_inputs_fail_before_pub(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            manifest = json.loads((ROOT / 'tools/ci/flutter_setup/vendor-locks.json').read_text())
            for name in ['tools/ci/flutter_setup/vendor-locks.json',
                         'clients/flutter/packages/livekit_client/pubspec.yaml',
                         'tools/ci/flutter_setup/locks/livekit_client.lock',
                         'clients/flutter/packages/livekit_client/example/pubspec.yaml',
                         'tools/ci/flutter_setup/locks/livekit_example.lock']:
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((ROOT/name).read_bytes())
            vendor_locks.validate(root,'livekit_client')
            path=root/'clients/flutter/packages/livekit_client/pubspec.yaml';path.write_text(path.read_text()+'\n')
            with self.assertRaises(ValueError): vendor_locks.validate(root,'livekit_client')
            path.write_bytes((ROOT/'clients/flutter/packages/livekit_client/pubspec.yaml').read_bytes())
            lock=root/'clients/flutter/packages/livekit_client/pubspec.lock';lock.symlink_to(path)
            with self.assertRaises(ValueError): vendor_locks.prepare(root,'livekit_client')
            with self.assertRaises(ValueError): vendor_locks.validate(root,'foreign')

    def test_native_runner_always_enforces_vendor_locks_before_tests(self):
        from unittest.mock import patch, call
        from tools.ci.native import flutter
        from tools.ci.flutter_gates import profiles
        machine = json.dumps({'frameworkVersion':'3.47.7', 'dartSdkVersion':'3.13.5',
                              'frameworkRevision':'abaf9c523780a608bd46686fd5e53740a07077f8'})
        pool = dict(RUNNER_ENVIRONMENT='self-hosted', RUNNER_OS='Linux',
                    RUNNER_NAME='BOOHTACORD-Hetzner-CI-1-test', BOOHTACORD_EPHEMERAL_GUEST='true')
        for env, extra in (({}, ()), (pool, ('--concurrency=2',))):
            events = []
            with self.subTest(environment=env.get('RUNNER_ENVIRONMENT', 'local')), \
                    patch.dict('os.environ', env, clear=True), patch.object(profiles,'output',return_value=machine), \
                    patch.object(profiles,'run',side_effect=lambda *a, **k: events.append(('run', a, k.get('cwd')))) as run, \
                    patch.object(profiles,'prepare',side_effect=lambda root, name: events.append(('lock', name))) as prepare:
                flutter.main()
            self.assertEqual(prepare.call_count,2)
            for name in ('livekit_client','flutter_webrtc'):
                path=ROOT/'clients/flutter/packages'/name
                pub=('flutter','pub','get','--enforce-lockfile')
                test=('flutter','test','--no-pub',*extra)
                self.assertIn(call(*pub,cwd=path),run.call_args_list)
                self.assertIn(call(*test,cwd=path),run.call_args_list)
                self.assertLess(events.index(('lock',name)),events.index(('run',pub,path)))
                self.assertLess(events.index(('run',pub,path)),events.index(('run',test,path)))

    def test_recursive_example_analyzer_keeps_its_own_reviewed_lock(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name).resolve()
            projects={'livekit_client':'livekit_client','flutter_webrtc':'flutter_webrtc','livekit_example':'livekit_client/example'}
            files=['tools/ci/flutter_setup/vendor-locks.json']
            for package,folder in projects.items():
                files += ['clients/flutter/packages/'+folder+'/pubspec.yaml','tools/ci/flutter_setup/locks/'+package+'.lock']
            for file in files:
                p=root/file;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/file).read_bytes())
            vendor_locks.prepare(root,'livekit_client')
            for package in ('livekit_client','livekit_example'):
                target=root/'clients/flutter/packages'/projects[package]/'pubspec.lock'
                self.assertEqual(target.read_bytes(),vendor_locks.validate(root,package))
