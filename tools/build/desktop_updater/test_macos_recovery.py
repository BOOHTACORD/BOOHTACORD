"""Real monitor preflight tests; these do not certify an application upgrade."""
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path

from .recovery import macos


@unittest.skipUnless(sys.platform == 'darwin', 'requires macOS codesign and Cocoa')
class MacRecoveryPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.monitor_app = macos()
        cls.monitor = cls.monitor_app / 'Contents/MacOS/BOOHTACORDRecovery'

    def setUp(self):
        applications = Path.home() / 'Applications'
        applications.mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(
            prefix='BOOHTACORD-monitor-test-', dir=applications)
        self.root = Path(self.temporary.name)
        self.parent = self.root / 'Installed Пример'
        self.parent.mkdir()
        self.recovery = self.root / 'DesktopUpdates/recovery'
        binary = self.recovery / 'previous.app/Contents/MacOS/Fixture'
        binary.parent.mkdir(parents=True)
        source = self.root / 'fixture.c'
        source.write_text('int main(void) { return 0; }\n')
        subprocess.run(['xcrun', 'clang', str(source), '-o', str(binary)],
                       check=True, capture_output=True)
        (binary.parent.parent / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'ru.boohtacord.boohtacordDesktop',
            'CFBundleVersion': '77', 'CFBundleExecutable': 'Fixture',
            'CFBundlePackageType': 'APPL',
        }))
        subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-',
                        str(binary.parent.parent.parent)],
                       check=True, capture_output=True)
        self.transaction = str(uuid.uuid4())
        self.plan = self.recovery / 'plan.json'

    def tearDown(self):
        self.parent.chmod(0o700)
        self.temporary.cleanup()

    def run_monitor(self, target, monitor=None, retain=False, environment=None):
        self.plan.write_text(json.dumps({
            'schema_version': 1, 'transaction': self.transaction,
            'target': str(target), 'backup': str(self.recovery / 'previous.app'),
            'old_pid': os.getpid(), 'old_build': '77', 'new_build': '78',
            'new_release': 'native-test',
        }))
        # The cancellation is local and deliberate. Never launch or replace a
        # fixture app; inspect only preflight with a genuine signed baseline.
        (self.recovery / 'cancel.json').write_text(json.dumps({
            'transaction': self.transaction,
        }))
        subprocess.run([str(monitor or self.monitor), '--plan', str(self.plan),
                        '--resumed', *(['--retain-installed'] if retain else [])],
                       check=True, timeout=15, capture_output=True, env=environment)
        return json.loads((self.recovery / 'recovery-outcome.json').read_text())

    def installed_monitor(self):
        target = self.parent / 'BOOHTACORD.app'
        shutil.copytree(self.recovery / 'previous.app', target)
        embedded = target / 'Contents/Resources/BOOHTACORDRecovery.app'
        shutil.copytree(self.monitor_app, embedded)
        subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', str(target)],
                       check=True, capture_output=True)
        return target, embedded / 'Contents/MacOS/BOOHTACORDRecovery'

    def test_installed_monitor_retains_verified_baseline_and_itself(self):
        target, monitor = self.installed_monitor()
        shutil.rmtree(self.recovery / 'previous.app')
        result = self.run_monitor(target, monitor, retain=True)
        self.assertEqual(result['status'], 'cancelled')
        baseline = self.recovery / 'previous.app'
        self.assertEqual((baseline / 'Contents/MacOS/Fixture').read_bytes(),
                         (target / 'Contents/MacOS/Fixture').read_bytes())
        retained = self.recovery / 'BOOHTACORDRecovery.app'
        self.assertEqual((retained / 'Contents/MacOS/BOOHTACORDRecovery').read_bytes(),
                         monitor.read_bytes())
        subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict',
                        str(baseline)], check=True, capture_output=True)

    def test_retention_rejects_monitor_outside_installed_bundle(self):
        target, _ = self.installed_monitor()
        result = self.run_monitor(target, retain=True)
        self.assertEqual(result['reason'], 'monitor_identity')
        self.assertFalse((self.recovery / 'recovery-ready.json').exists())

    def test_container_home_does_not_redefine_the_users_installation_directory(self):
        target, monitor = self.installed_monitor()
        shutil.rmtree(self.recovery / 'previous.app')
        container = self.root / 'ContainerHome'
        container.mkdir()
        environment = dict(os.environ, CFFIXED_USER_HOME=str(container), HOME=str(container))
        result = self.run_monitor(target, monitor, retain=True, environment=environment)
        self.assertEqual(result['status'], 'cancelled')
        self.assertTrue((self.recovery / 'recovery-ready.json').exists())

    def test_unwritable_parent_rejects_before_ready(self):
        self.parent.chmod(0o500)
        result = self.run_monitor(self.parent / 'BOOHTACORD.app')
        self.assertEqual(result['reason'], 'replace_denied')
        self.assertEqual(result['status'], 'manualRecovery')
        self.assertFalse((self.recovery / 'recovery-ready.json').exists())

    def test_missing_parent_rejects_before_ready(self):
        result = self.run_monitor(self.parent / 'missing/BOOHTACORD.app')
        self.assertEqual(result['reason'], 'recovery_volume')
        self.assertFalse((self.recovery / 'recovery-ready.json').exists())

    def test_writable_parent_cancels_without_replacing_anything(self):
        result = self.run_monitor(self.parent / 'BOOHTACORD.app')
        self.assertEqual(result['status'], 'cancelled')
        self.assertTrue((self.recovery / 'recovery-ready.json').exists())
        self.assertEqual(list(self.parent.iterdir()), [])
        self.assertTrue((self.recovery / 'previous.app').is_dir())

    def test_missing_plan_argument_is_rejected(self):
        result = subprocess.run([str(self.monitor)], capture_output=True)
        self.assertEqual(result.returncode, 2)
