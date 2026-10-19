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
                         'tools/ci/flutter_setup/locks/livekit_client.lock']:
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
        with patch.object(flutter,'output',return_value='{"frameworkVersion":"3.47.7","dartSdkVersion":"3.13.5"}'), \
             patch.object(flutter,'run') as run, patch.object(vendor_locks,'prepare') as prepare:
            flutter.main()
        self.assertEqual(prepare.call_count,2)
        for name in ('livekit_client','flutter_webrtc'):
            path=ROOT/'clients/flutter/packages'/name
            self.assertIn(call('flutter','pub','get','--enforce-lockfile',cwd=path),run.call_args_list)
            self.assertIn(call('flutter','test','--no-pub',cwd=path),run.call_args_list)
