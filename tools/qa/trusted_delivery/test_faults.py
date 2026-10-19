"""A transport negative must fail at its intended stage, never at an unrelated guard."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from .faults import require_failure
from tools.release.delivery.phases import LIMITS


def failed(phase,code):
    rows=[]
    for name,limit in LIMITS.items():
        bad=name==phase
        rows.append({'phase':name,'limit_seconds':limit,'status':'FAIL' if bad else 'PASS',
                     'failure_code':code if bad else None,'exit_code':1 if bad and code=='exit' else None,'elapsed_seconds':.1})
        if bad:break
    return {'schema_version':1,'kind':'delivery-phases','source_revision':'a'*40,
            'controller_revision':'b'*40,'status':'FAIL','phases':rows}


class ActualFailureReceiptTests(unittest.TestCase):
    def test_unexpected_green_is_retained_before_refusing_the_negative(self):
        from . import faults
        from .test_evidence import delivery
        with tempfile.TemporaryDirectory() as temporary:
            work=Path(temporary);value=delivery('b'*40,'a'*40)
            (work/'attempt-ssh-refused.json').write_text(json.dumps(value))
            process=Mock();process.wait.return_value=0;process.poll.return_value=0
            with patch.object(faults,'observe',return_value={}),patch.object(faults,'running',return_value={}),\
                    patch.object(faults,'attempt',return_value=process),\
                    patch('tools.release.bundle.verify.verify_bundle'),self.assertRaises(RuntimeError):
                faults.run(work,dict(baseline='a'*40,next='b'*40,controller='c'*40))
            retained=json.loads((work/'negative-runtime.json').read_text())
            self.assertEqual('FAIL',retained['status'])
            self.assertEqual(value,retained['attempts'][0]['delivery'])

    def test_unexpected_failure_stage_remains_failed_with_its_original_public_receipt(self):
        from . import faults
        with tempfile.TemporaryDirectory() as temporary:
            work=Path(temporary)
            value=failed('history','exit')
            value.update(source_revision='b'*40,controller_revision='c'*40)
            (work/'attempt-ssh-refused.json').write_text(json.dumps(value))
            process=Mock();process.wait.return_value=1;process.poll.return_value=1
            with patch.object(faults,'observe',return_value={}),patch.object(faults,'running',return_value={}),\
                    patch.object(faults,'attempt',return_value=process),\
                    patch('tools.release.bundle.verify.verify_bundle'),self.assertRaises(ValueError):
                faults.run(work,dict(baseline='a'*40,next='b'*40,controller='c'*40))
            retained=json.loads((work/'negative-runtime.json').read_text())
            self.assertEqual('FAIL',retained['status'])
            self.assertEqual(value,retained['attempts'][0]['delivery'])
            self.assertEqual('history',retained['attempts'][0]['delivery']['phases'][-1]['phase'])

    def test_expected_exit_or_real_timeout_is_required_at_the_actual_failure_stage(self):
        cases={'ssh-refused':('current_revision','exit'),'scp-timeout':('transfer_bundle','timeout'),
               'immutable':('remote_install','exit'),'downgrade':('history','exit')}
        for name,(phase,code) in cases.items():
            original=failed(phase,code)
            require_failure(name,original)
            for mutation in ('green','wrong_stage','wrong_code','private'):
                value=deepcopy(original)
                if mutation=='green':value['status']='PASS'
                if mutation=='wrong_stage':value=failed('current_revision','exit') if phase!='current_revision' else failed('history','exit')
                if mutation=='wrong_code':value['phases'][-1]['failure_code']='execution'
                if mutation=='private':value['private_canary']='forbidden'
                with self.subTest(name=name,mutation=mutation),self.assertRaises(ValueError):require_failure(name,value)
