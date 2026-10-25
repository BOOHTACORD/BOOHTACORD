"""Executable schema/fixture privacy checks; provider/OS delivery stays separate."""
import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate_spec

ROOT=Path(__file__).resolve().parents[3]
def read(name):return json.loads((ROOT/'contracts'/name).read_text(encoding='utf-8-sig'))

class NotificationContracts(unittest.TestCase):
    def test_external_payload_rejects_private_fields_and_bad_dates(self):
        schema=read('notification-payload-v1.schema.json')
        self.assertEqual({'version','generation','binding_ref','notification_ref','group_ref','template','expires_at'},set(schema['properties']))
        valid={'version':1,'generation':1,'binding_ref':'11111111-1111-4111-8111-111111111111','notification_ref':'22222222-2222-4222-8222-222222222222','group_ref':'33333333-3333-4333-8333-333333333333','template':'direct_message','expires_at':'2026-10-25T12:00:00Z'}
        validator=Draft202012Validator(schema,format_checker=FormatChecker());validator.validate(valid)
        for private in ('body','sender_name','account_id','session_id','endpoint','url','attachment'):
            self.assertTrue(list(validator.iter_errors({**valid,private:'synthetic-private'})))
        for expiry in ('2026-02-29T00:00:00Z','2026-10-25T12:00:00+01:00'):
            self.assertTrue(list(validator.iter_errors({**valid,'expires_at':expiry})))

    def test_relay_contract_is_separate_signature_authenticated_and_bounded(self):
        document=read('notification-relay-v1.openapi.json');validate_spec(document)
        self.assertEqual(8,len(document['paths']))
        for path,item in document['paths'].items():
            for operation in item.values():
                expected=[] if path in ('/health','/v1/devices/challenge') else [{'RelaySignature':[]}]
                self.assertEqual(expected,operation['security'])
        challenge=document['components']['schemas']['Enrollment']
        self.assertNotIn('nonce',challenge['properties']);self.assertNotIn('target',challenge['properties'])
        self.assertFalse(challenge['additionalProperties'])

if __name__=='__main__':unittest.main()
