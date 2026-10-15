"""Real monitor preflight tests; these do not certify an application upgrade."""
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

if sys.platform == 'darwin':
    import fcntl
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

    def test_launch_services_reports_started_while_monitor_waits(self):
        target, monitor = self.installed_monitor()
        shutil.rmtree(self.recovery / 'previous.app')
        self.plan.write_text(json.dumps({
            'schema_version': 1, 'transaction': self.transaction,
            'target': str(target), 'backup': str(self.recovery / 'previous.app'),
            'old_pid': os.getpid(), 'old_build': '77', 'new_build': '78',
            'new_release': 'native-test',
        }))
        source = self.root / 'launch.m'
        source.write_text(r'''#import <Cocoa/Cocoa.h>
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    __block BOOL done = NO, launched = NO;
    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
    config.activates = NO;
    config.arguments = @[@"--plan", @(argv[2]), @"--resumed", @"--retain-installed"];
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:@(argv[1])]
      configuration:config completionHandler:^(NSRunningApplication *app, NSError *error) {
        launched = app != nil && error == nil;
        done = YES;
      }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!done && [NSDate.date compare:deadline] == NSOrderedAscending)
      [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    puts(done ? (launched ? "LAUNCHED" : "FAILED") : "TIMED_OUT");
    return 0;
  }
}
''')
        launcher = self.root / 'launch'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Cocoa',
                        str(source), '-o', str(launcher)], check=True, capture_output=True)
        try:
            result = subprocess.run([str(launcher), str(monitor.parent.parent.parent),
                                     str(self.plan)], check=True, timeout=10,
                                    capture_output=True, text=True)
            # A completed preflight is separate from LaunchServices reporting
            # successful launch; both must happen before cancelling this fixture.
            deadline = time.monotonic() + 5
            ready = self.recovery / 'recovery-ready.json'
            outcome = self.recovery / 'recovery-outcome.json'
            while not ready.exists() and not outcome.exists() and time.monotonic() < deadline:
                time.sleep(.05)
            self.assertEqual(result.stdout.strip(), 'LAUNCHED')
            reason = json.loads(outcome.read_text()).get('reason') if outcome.exists() else 'no_outcome'
            self.assertTrue(ready.exists(), 'preflight:' + reason)
        finally:
            (self.recovery / 'cancel.json').write_text(json.dumps({
                'transaction': self.transaction,
            }))
            deadline = time.monotonic() + 5
            outcome = self.recovery / 'recovery-outcome.json'
            while not outcome.exists() and time.monotonic() < deadline:
                time.sleep(.05)
            self.assertTrue(outcome.exists(), 'Owned monitor must honor cancellation')

    def reset_recovery(self):
        source = self.root / 'reset.m'
        header = Path(__file__).resolve().parents[3] / 'clients/flutter/native/desktop_recovery/macos_state.h'
        source.write_text('#import "' + str(header) + '"\nint main(int argc, const char *argv[]) { @autoreleasepool { return ResetInactiveRecovery(@(argv[1])) ? 0 : 3; } }\n')
        binary = self.root / 'reset'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', str(source), '-o', str(binary)], check=True, capture_output=True)
        return subprocess.run([str(binary), str(self.recovery)], capture_output=True).returncode

    def pending_recovery(self, cancelled=True):
        self.plan.write_text(json.dumps({'transaction': self.transaction}))
        if cancelled:
            (self.recovery / 'cancel.json').write_text(json.dumps({'transaction': self.transaction}))
        lock = self.recovery / 'recovery.lock'
        lock.touch()
        return lock

    def test_cancelled_unstarted_monitor_can_retry_without_replacing_lock_inode(self):
        lock = self.pending_recovery()
        inode = lock.stat().st_ino
        self.assertEqual(self.reset_recovery(), 0)
        self.assertEqual(lock.stat().st_ino, inode)
        self.assertFalse(self.plan.exists())
        retired = list((self.recovery / 'retired').iterdir())
        self.assertEqual(len(retired), 1)
        self.assertTrue((retired[0] / 'previous.app/Contents/MacOS/Fixture').is_file())
        self.assertTrue((retired[0] / 'plan.json').is_file())
        self.assertEqual(self.reset_recovery(), 0)

    def test_an_active_monitor_cannot_be_reset_even_with_cancellation(self):
        lock = self.pending_recovery()
        with lock.open('rb') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.reset_recovery(), 3)
            self.assertTrue(self.plan.exists())
            self.assertTrue((self.recovery / 'previous.app').is_dir())

    def test_partial_retirement_can_resume_without_overwriting_history(self):
        self.pending_recovery()
        archive = self.recovery / 'retired' / self.transaction
        archive.mkdir(parents=True)
        self.assertEqual(self.reset_recovery(), 0)
        self.assertTrue((archive / 'plan.json').exists())
        self.assertTrue((archive / 'previous.app').is_dir())

    def test_finished_attempt_is_retired_and_history_is_bounded(self):
        lock = self.pending_recovery(cancelled=False)
        inode = lock.stat().st_ino
        for _ in range(5):
            self.transaction = str(uuid.uuid4())
            self.plan.write_text(json.dumps({'transaction': self.transaction}))
            (self.recovery / 'recovery-outcome.json').write_text(json.dumps({'transaction': self.transaction, 'status': 'completed'}))
            self.assertEqual(self.reset_recovery(), 0)
        self.assertEqual(lock.stat().st_ino, inode)
        self.assertEqual(len(list((self.recovery / 'retired').iterdir())), 3)

    def test_uncancelled_or_mismatched_attempt_is_preserved(self):
        self.pending_recovery(cancelled=False)
        self.assertEqual(self.reset_recovery(), 3)
        (self.recovery / 'cancel.json').write_text(json.dumps({'transaction': str(uuid.uuid4())}))
        self.assertEqual(self.reset_recovery(), 3)
        self.assertTrue(self.plan.exists())

    def test_unique_transaction_plan_does_not_reuse_legacy_path(self):
        self.plan = self.recovery / ('plan-' + self.transaction + '.json')
        result = self.run_monitor(self.parent / 'BOOHTACORD.app')
        self.assertEqual(result['status'], 'cancelled')
        self.assertFalse((self.recovery / 'plan.json').exists())

    def test_missing_plan_argument_is_rejected(self):
        result = subprocess.run([str(self.monitor)], capture_output=True)
        self.assertEqual(result.returncode, 2)
