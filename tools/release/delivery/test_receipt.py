"""Sanitized publication cannot turn a skipped or failed delivery into success."""
import json
import unittest
from . import receipt
from .phases import LIMITS
from .test_readback_contract import fixture, SHA, CONTROLLER


def result():
    return {'schema_version':1,'kind':'delivery-phases','source_revision':SHA,'controller_revision':CONTROLLER,
            'status':'PASS','phases':[{'phase':name,'limit_seconds':limit,'status':'PASS','failure_code':None,
                                      'exit_code':None,'elapsed_seconds':1.0} for name,limit in LIMITS.items()],
            'readback':fixture()}


def outcomes(): return {key:'success' for key in receipt.STEPS}


class DeliveryReceiptTests(unittest.TestCase):
    def test_only_complete_successful_steps_and_fresh_readback_are_pass(self):
        value=receipt.build(outcomes(),result())
        self.assertEqual('PASS',value['status']); self.assertEqual('NOT_ASSERTED',value['human_approval'])
        self.assertEqual(SHA,value['delivery']['source_revision'])

    def test_skipped_failed_cancelled_missing_or_incomplete_steps_never_become_pass(self):
        for state in ('skipped','failure','cancelled','',None):
            states=outcomes(); states['producer']=state
            self.assertEqual('FAIL',receipt.build(states,result())['status'])
        for value in (None,{}, {**result(),'status':'FAIL'}, {**result(),'phases':[]}):
            self.assertEqual('FAIL',receipt.build(outcomes(),value)['status'])

    def test_private_extra_fields_errors_or_malformed_rows_are_not_republished(self):
        for mutation in ('extra','phase','code','body'):
            value=result()
            if mutation=='extra': value['private']='private-canary'
            if mutation=='phase': value['phases'][0]['phase']='private-canary'
            if mutation=='code': value['phases'][0]['failure_code']='private-canary'
            if mutation=='body': value['readback']['private']='private-canary'
            output=receipt.build(outcomes(),value)
            self.assertNotIn('canary',json.dumps(output)); self.assertEqual('FAIL',output['status'])

    def test_valid_failed_phase_is_retained_without_claiming_remote_process_stopped(self):
        value=result(); value.pop('readback'); value['status']='FAIL'; value['phases']=value['phases'][:3]
        value['phases'][-1].update(status='FAIL',failure_code='timeout')
        output=receipt.build(outcomes(),value)
        self.assertEqual('FAIL',output['status'])
        self.assertEqual('timeout',output['delivery']['phases'][-1]['failure_code'])
        self.assertEqual('UNKNOWN',output['remote_completion'])

    def test_public_producer_authority_rejects_extra_private_fields_or_loose_names(self):
        from .test_producer_artifacts import fixtures
        from .producer_artifacts import select
        run,document=fixtures(); value=select(123,run,document,'owner/repo',True)
        self.assertEqual(value,receipt.authority(value))
        for field,change in [('private','private-canary'),('name','server-latest'),('run_id',True),('digest',None)]:
            invalid={**value,field:change}
            with self.subTest(field=field),self.assertRaises(ValueError): receipt.authority(invalid)
