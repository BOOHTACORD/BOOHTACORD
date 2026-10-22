"""A successful subprocess is not by itself a complete installed-source verdict."""
import json
import unittest
from .phases import Phases, PhaseFailed, ReportedFailure
from .commands import ExecutionFailed

SOURCE = 'a' * 40
ORDER = ('current_revision', 'history', 'transfer_bundle', 'transfer_driver', 'remote_install', 'readback')


class DeliveryPhaseTests(unittest.TestCase):
    def phase(self, executor=lambda *a, **k: b'controlled'):
        ticks = iter(range(50))
        return Phases(SOURCE, 'b' * 40, executor=executor, clock=lambda: next(ticks))

    def test_incomplete_or_reordered_execution_never_becomes_healthy(self):
        value = self.phase()
        with self.assertRaises(ValueError): value.complete()
        with self.assertRaises(ValueError): value.run('remote_install', ['controlled'])
        for name in ORDER[:-1]: value.run(name, ['controlled'])
        with self.assertRaises(ValueError): value.complete()
        value.run('readback', ['controlled'], validator=lambda data: {'source_revision': SOURCE})
        result = value.complete()
        self.assertEqual('PASS', result['status'])
        self.assertEqual(list(ORDER), [r['phase'] for r in result['phases']])
        self.assertTrue(all(r['elapsed_seconds'] == 1 and r['status'] == 'PASS' for r in result['phases']))

    def test_slow_bundle_transfer_has_a_finite_budget_with_room_for_install_and_readback(self):
        def measured_transfer(argv, timeout, **kwargs):
            # The failed 85 MB delivery copied 35 MB in 300s: allow 12 minutes.
            if argv[0]=='scp' and timeout < 720:
                raise ExecutionFailed('timeout')
            return b'controlled'
        value=self.phase(measured_transfer)
        value.run('current_revision',['controlled'])
        value.run('history',['controlled'])
        value.run('transfer_bundle',['scp','controlled-bundle'])
        row=value.rows[-1]
        self.assertEqual('PASS',row['status'])
        self.assertEqual(900,row['limit_seconds'])
        from .phases import LIMITS
        self.assertTrue(all(0 < limit <= 900 for limit in LIMITS.values()))
        self.assertLess(sum(LIMITS.values())+120,30*60)

    def test_timeout_records_safe_phase_and_does_not_allow_later_steps(self):
        def failed(*args, **kwargs): raise ExecutionFailed('timeout')
        value = self.phase(failed)
        with self.assertRaises(PhaseFailed): value.run('current_revision', ['private-canary'])
        result = value.failure()
        self.assertEqual('FAIL', result['status'])
        self.assertEqual('timeout', result['phases'][0]['failure_code'])
        self.assertNotIn('private-canary', json.dumps(result))
        with self.assertRaises(ValueError): value.run('history', ['controlled'])
        with self.assertRaises(ValueError): value.complete()

    def test_zero_exit_with_invalid_readback_cannot_be_pass(self):
        value = self.phase()
        for name in ORDER[:-1]: value.run(name, ['controlled'])
        def invalid(raw): raise ValueError('private-response-body-canary')
        with self.assertRaises(PhaseFailed):
            value.run('readback', ['controlled'], validator=invalid, capture_limit=4096)
        result = value.failure()
        self.assertEqual('invalid_output', result['phases'][-1]['failure_code'])
        self.assertNotIn('canary', json.dumps(result))
        with self.assertRaises(ValueError): value.complete()

    def test_identity_is_validated_before_any_process(self):
        for source, controller in [('canary', 'b'*40), (SOURCE, 'bad')]:
            with self.subTest(source=source), self.assertRaises(ValueError): Phases(source, controller)

    def test_unexpected_validator_error_does_not_publish_response_body(self):
        value = self.phase()
        def invalid(raw): raise RuntimeError('private-response-canary')
        with self.assertRaises(PhaseFailed) as result:
            value.run('current_revision', ['controlled'], validator=invalid)
        self.assertNotIn('canary', str(result.exception))
        self.assertEqual('invalid_output', value.failure()['phases'][0]['failure_code'])

    def test_validated_remote_install_failure_is_preserved_as_a_safe_subphase(self):
        value = self.phase()
        for name in ORDER[:-1]:
            if name == 'remote_install':
                def failed(raw): raise ReportedFailure('deployment')
                with self.assertRaises(PhaseFailed):
                    value.run(name, ['controlled'], validator=failed, capture_limit=1024)
                break
            value.run(name, ['controlled'])
        row = value.failure()['phases'][-1]
        self.assertEqual('remote_install', row['phase'])
        self.assertEqual('installer_deployment', row['failure_code'])
        self.assertIsNone(row['exit_code'])
        self.assertNotIn('canary', json.dumps(value.failure()))

    def test_interruption_or_unexpected_execution_error_is_a_failed_stage(self):
        for exception,code in [(SystemExit(143),'interrupted'), (RuntimeError('private-canary'),'execution')]:
            def fail(*args,**kwargs): raise exception
            value=self.phase(fail)
            with self.subTest(code=code),self.assertRaises((SystemExit,PhaseFailed)):
                value.run('current_revision',['controlled'])
            receipt=value.failure()
            self.assertEqual(code,receipt['phases'][0]['failure_code'])
            self.assertNotIn('canary',json.dumps(receipt))
