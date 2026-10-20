"""Exercise the guest launcher in a private substitute home with a fake agent."""
from pathlib import Path
import subprocess
import tempfile
import unittest


class LauncherTests(unittest.TestCase):
    def test_job_compilers_share_a_bounded_heap_and_cannot_leave_persistent_daemons(self):
        source=Path(__file__).with_name('start-runner.sh').read_text()
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary)/'runner'; agent=home/'actions-runner';agent.mkdir(parents=True)
            (home/'.jit').write_text('isolated-test-value')
            fake=agent/'run.sh'
            fake.write_text('#!/bin/bash\nset -eu\ntest "$#" = 2\ntest "$1" = --jitconfig\ntest ! -e ../.jit\n')
            fake.chmod(0o700)
            result=subprocess.run(['bash'],input=source.replace('/home/runner',str(home)),
                                  text=True,capture_output=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse((home/'.jit').exists())
            profile=dict(row.split('=',1) for row in (home/'.gradle/gradle.properties').read_text().splitlines())
            self.assertEqual(profile['org.gradle.daemon'],'false')
            self.assertEqual(profile['kotlin.compiler.execution.strategy'],'in-process')
            self.assertIn('-Xmx2560m',profile['org.gradle.jvmargs'])
            self.assertEqual(profile['org.gradle.workers.max'],'2')
