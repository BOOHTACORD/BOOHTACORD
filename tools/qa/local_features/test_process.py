import subprocess
import os
import signal
import sys
import tempfile
import time
import unittest
from pathlib import Path
from .process import run_owned


class ProcessCleanupTests(unittest.TestCase):
    def test_command_failure_is_preserved(self):
        with self.assertRaises(subprocess.CalledProcessError) as failure:
            run_owned([sys.executable,'-c','raise SystemExit(7)'],timeout=5)
        self.assertEqual(failure.exception.returncode,7)

    def test_timeout_terminates_the_owned_descendant(self):
        with tempfile.TemporaryDirectory() as temporary:
            stopped=Path(temporary)/'stopped'
            child="import signal,time,sys;from pathlib import Path;signal.signal(signal.SIGTERM,lambda *_:(Path(sys.argv[1]).write_text('stopped'),sys.exit(0)));time.sleep(30)"
            parent="import subprocess,sys;subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]).wait()"
            with self.assertRaises(subprocess.TimeoutExpired):
                run_owned([sys.executable,'-c',parent,child,str(stopped)],timeout=1)
            deadline=time.monotonic()+2
            while not stopped.exists() and time.monotonic()<deadline:time.sleep(.01)
            self.assertEqual(stopped.read_text(),'stopped')

    def test_timeout_stops_a_descendant_that_ignores_termination(self):
        with tempfile.TemporaryDirectory() as temporary:
            identity=Path(temporary)/'child'
            child="import os,signal,time,sys;from pathlib import Path;signal.signal(signal.SIGTERM,signal.SIG_IGN);Path(sys.argv[1]).write_text(str(os.getpid()));time.sleep(30)"
            parent="import subprocess,sys;subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]).wait()"
            pid=None
            try:
                with self.assertRaises(subprocess.TimeoutExpired):
                    run_owned([sys.executable,'-c',parent,child,str(identity)],timeout=1)
                pid=int(identity.read_text())
                state=subprocess.run(['/bin/ps','-p',str(pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
                self.assertTrue(not state or state.startswith('Z'),state)
            finally:
                if identity.exists():
                    try:os.kill(int(identity.read_text()),signal.SIGKILL)
                    except ProcessLookupError:pass
