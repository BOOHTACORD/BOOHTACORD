"""Startup polling must never retry credentials, assertions or unknown failures."""
import contextlib
import io
from types import SimpleNamespace
import unittest
from .readiness import wait_roomservice

PREFIX='LiveKit private path preflight failed: LiveKit private RoomService preflight failed ('
REFUSED=PREFIX+'roomservice ConnectionRefusedError).\n'


class ReadinessTests(unittest.TestCase):
    def observe(self, outputs, budget=10):
        now=[0.0];calls=[]
        def run(command,**kwargs):
            calls.append(kwargs);return outputs.pop(0) if outputs else SimpleNamespace(returncode=1,stdout=REFUSED)
        def sleep(seconds): now[0]+=seconds
        with contextlib.redirect_stdout(io.StringIO()):
            result=wait_roomservice(['owned-probe'],budget=budget,runner=run,clock=lambda:now[0],sleep=sleep)
        return result,calls

    def test_real_success_required_after_the_old_three_attempt_window(self):
        result,calls=self.observe([*[SimpleNamespace(returncode=1,stdout=REFUSED)]*4,SimpleNamespace(returncode=0,stdout='ready')])
        self.assertEqual(result['status'],'PASS');self.assertEqual(result['attempts'],5)
        self.assertEqual(result['connection_refused_retries'],4)
        self.assertGreaterEqual(result['elapsed_seconds'],4)
        self.assertTrue(all(0<c['timeout']<=10 for c in calls))

    def test_persistent_refusal_hits_a_bounded_deadline_without_pass(self):
        with self.assertRaises(TimeoutError): self.observe([],budget=3)

    def test_auth_endpoint_and_unknown_failures_are_not_retried_or_logged(self):
        for value in (PREFIX+'roomservice unauthenticated HTTP 401).',PREFIX+'dns private_endpoint_mismatch).','PRIVATE-CANARY cookie-token'):
            calls=[];stream=io.StringIO()
            def run(*args,**kwargs):calls.append(1);return SimpleNamespace(returncode=1,stdout=value)
            with self.subTest(value=value),contextlib.redirect_stdout(stream),self.assertRaises(RuntimeError):
                wait_roomservice(['owned-probe'],runner=run)
            self.assertEqual(len(calls),1)
            self.assertNotIn('PRIVATE-CANARY',stream.getvalue());self.assertNotIn('cookie-token',stream.getvalue())

    def test_invalid_deadline_and_probe_exception_cannot_become_ready(self):
        for budget in (0,-1,61,float('nan')):
            with self.subTest(budget=budget),self.assertRaises(ValueError): wait_roomservice([],budget=budget)
        def broken(*a,**k): raise OSError('controlled')
        with self.assertRaises(OSError): wait_roomservice(['owned-probe'],runner=broken)
