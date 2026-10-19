"""Real owned subprocess boundaries, including noisy output and process trees."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch
from .commands import execute, stop, ExecutionFailed


class DeliveryCommandTests(unittest.TestCase):
    def test_capture_is_bounded_and_stderr_never_enters_public_error(self):
        self.assertEqual(b'public', execute([sys.executable, '-c', 'print("public",end="")'], 3, capture_limit=16))
        with self.assertRaises(ExecutionFailed) as result:
            execute([sys.executable, '-c', 'import sys;sys.stderr.write("private-canary");sys.exit(7)'], 3)
        self.assertEqual(('exit', 7), (result.exception.code, result.exception.returncode))
        self.assertNotIn('private-canary', str(result.exception))

    def test_stdout_overflow_fails_instead_of_truncating_a_result_to_pass(self):
        with self.assertRaises(ExecutionFailed) as result:
            execute([sys.executable, '-c', 'print("x"*1000000)'], 3, capture_limit=32)
        self.assertEqual('output', result.exception.code)

    def test_missing_program_is_sanitized_without_echoing_argv(self):
        with self.assertRaises(ExecutionFailed) as result:
            execute(['/missing-private-canary-executable'], 3)
        self.assertEqual('start', result.exception.code)
        self.assertNotIn('private-canary', str(result.exception))

    def test_deadline_terminates_owned_descendants_even_if_they_ignore_term(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'pid'
            script = ('import subprocess,sys,time;'
                      'p=subprocess.Popen([sys.executable,"-c",'
                      '"import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(60)"]);'
                      'open(sys.argv[1],"w").write(str(p.pid));time.sleep(60)')
            started = time.monotonic()
            with self.assertRaises(ExecutionFailed) as result:
                execute([sys.executable, '-c', script, str(path)], 1.5)
            self.assertEqual('timeout', result.exception.code)
            self.assertLess(time.monotonic() - started, 5)
            child = int(path.read_text())
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                observed = subprocess.run(['ps', '-o', 'stat=', '-p', str(child)], capture_output=True, text=True)
                if not observed.stdout.strip() or observed.stdout.strip().startswith('Z'):
                    break
                time.sleep(.02)
            else:
                os.kill(child, 9)
                self.fail('Owned descendant survived the command timeout')

    def test_invalid_time_or_output_bounds_do_not_start_a_command(self):
        for timeout, limit in [(0, 0), (float('nan'), 0), (901, 0), (1, -1), (1, 65537)]:
            with self.subTest(timeout=timeout, limit=limit), self.assertRaises(ValueError):
                execute([sys.executable, '-c', 'raise SystemExit(99)'], timeout, capture_limit=limit)

    def test_failed_cleanup_does_not_expose_the_command_in_timeout_exception(self):
        process = Mock(pid=123, wait=Mock(side_effect=subprocess.TimeoutExpired(['private-canary'], 2)))
        with patch('tools.release.delivery.commands.os.killpg'):
            with self.assertRaises(ExecutionFailed) as result: stop(process)
        self.assertEqual('cleanup', result.exception.code)
        self.assertNotIn('private-canary', str(result.exception))
