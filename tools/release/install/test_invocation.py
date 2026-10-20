"""Real owned process signals/pipes must not abandon maintenance or its host lock."""
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest


@unittest.skipUnless(os.name == 'posix', 'Owned POSIX process group and flock')
class ReceivedInstallerInvocationTests(unittest.TestCase):
    def fixture(self, root, code):
        private = root / 'private'
        private.mkdir(mode=0o700)
        binary = root / 'bin'
        binary.mkdir()
        worker = binary / 'python3'
        worker.write_text('#!' + sys.executable + '\n' + '''import fcntl,os,sys,time
from pathlib import Path
root=Path(os.environ['QA_INVOCATION_ROOT'])
assert sys.argv[1:3]==['-m','tools.release.install.run']
with (root/'lock').open('a') as lock:
 fcntl.flock(lock,fcntl.LOCK_EX)
 (root/'maintenance').write_text('on')
 (root/'ready').touch()
 deadline=time.monotonic()+5
 while not (root/'release').exists():
  if time.monotonic()>deadline:raise RuntimeError('Owned fixture release timed out')
  time.sleep(.01)
 os.write(1,b'private-output-canary\\n');os.write(2,b'private-error-canary\\n')
 (root/'maintenance').write_text('off')
 (root/'worker-complete').touch()
sys.exit(int(os.environ['QA_INVOCATION_EXIT']))
''')
        worker.chmod(0o700)
        invocation = Path(__file__).with_name('invocation.sh')
        script = '\n'.join([
            'set -euo pipefail',
            'source ' + shlex.quote(str(invocation)),
            'trap \'printf cleanup > "$QA_INVOCATION_ROOT/cleanup"; rm -rf -- "$QA_INVOCATION_PRIVATE"\' EXIT',
            'run_received_installer /fixture/bundle ' + 'a'*40 + ' ' + 'b'*64 + ' ' + 'c'*40 + ' "$QA_INVOCATION_PRIVATE"',
            'printf complete > "$QA_INVOCATION_ROOT/parent-complete"',
        ])
        process = subprocess.Popen(['bash', '--noprofile', '--norc', '-c', script],
            env={**os.environ, 'PATH': str(binary) + os.pathsep + os.environ['PATH'],
                 'QA_INVOCATION_ROOT': str(root), 'QA_INVOCATION_PRIVATE': str(private),
                 'QA_INVOCATION_EXIT': str(code)},
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        self.addCleanup(self.stop, process)
        deadline = time.monotonic() + 5
        while not (root/'ready').exists():
            if process.poll() is not None or time.monotonic() > deadline:
                self.fail('Owned canonical invocation fixture did not start')
            time.sleep(.01)
        return process, private

    @staticmethod
    def stop(process):
        try: os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError: pass
        process.wait(timeout=5)
        for stream in (process.stdout, process.stderr):
            if stream is not None: stream.close()

    def assert_locked(self, root):
        import fcntl
        with (root/'lock').open('a') as lock:
            with self.assertRaises(BlockingIOError):
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_channel_hangup_and_closed_output_keep_worker_lock_until_cleanup_finishes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            process, private = self.fixture(root, 0)
            self.assert_locked(root)
            self.assertEqual(0o600, (private/'install-private.log').stat().st_mode & 0o777)
            process.stdout.close()
            process.stderr.close()
            os.killpg(process.pid, signal.SIGHUP)
            time.sleep(.05)
            self.assertIsNone(process.poll(), 'SSH hangup must not kill the lock-owning invocation')
            self.assert_locked(root)
            self.assertTrue(private.is_dir())
            self.assertFalse((root/'cleanup').exists())
            (root/'release').touch()
            self.assertEqual(0, process.wait(timeout=5))
            self.assertEqual('off', (root/'maintenance').read_text())
            self.assertTrue((root/'worker-complete').exists())
            self.assertTrue((root/'parent-complete').exists())
            self.assertTrue((root/'cleanup').exists())
            self.assertFalse(private.exists())

    def test_normal_exit_status_is_preserved_without_private_output_on_the_channel(self):
        for code in (0, 17):
            with self.subTest(exit_code=code), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                process, private = self.fixture(root, code)
                (root/'release').touch()
                out, err = process.communicate(timeout=5)
                self.assertEqual(code, process.returncode)
                self.assertEqual((b'', b''), (out, err))
                self.assertEqual('off', (root/'maintenance').read_text())
                self.assertTrue((root/'cleanup').exists())
                self.assertEqual(code == 0, (root/'parent-complete').exists())
                self.assertFalse(private.exists())
