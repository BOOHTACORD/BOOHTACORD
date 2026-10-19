"""A stale or unrelated healthy response cannot acknowledge a new transfer."""
from datetime import datetime, timezone
import json
import unittest
from . import readback_contract

SHA='a'*40
PRIOR='b'*40
CONTROLLER='c'*40
NONCE='d'*32


def fixture():
    return {'schema_version': 1, 'kind': 'installed-source-readback', 'status': 'PASS',
            'source_revision': SHA, 'controller_revision': CONTROLLER, 'nonce': NONCE,
            'previous_source_revision': PRIOR, 'persistent_volumes': 'PASS', 'schema_relation': 'unchanged',
            'migration_inventory_sha256': 'e'*64, 'running_images': {'api': 'sha256:'+'f'*64, 'web': 'sha256:'+'0'*64},
            'checked_at': datetime.now(timezone.utc).isoformat(), 'volumes': {n: '1'*64 for n in readback_contract.VOLUMES},
            'schema_sha256': '2'*64, 'health': 'PASS', 'sources': {'api': SHA, 'web': SHA}}


class TransferAcknowledgementTests(unittest.TestCase):
    def validate(self, value): return readback_contract.validate(json.dumps(value).encode(), SHA, CONTROLLER, PRIOR, NONCE)

    def test_exact_fresh_receipt_is_the_only_acknowledgement(self):
        self.assertEqual(fixture()['source_revision'], self.validate(fixture())['source_revision'])

    def test_stale_foreign_failed_or_incomplete_receipt_cannot_acknowledge_install(self):
        for field,value in [('source_revision', PRIOR), ('controller_revision', SHA), ('nonce', '0'*32),
                             ('previous_source_revision', SHA), ('health', 'FAIL'), ('status', 'FAIL'),
                             ('schema_version', True), ('persistent_volumes', 'FAIL'),
                             ('checked_at', '2020-01-01T00:00:00+00:00'), ('checked_at', 'bad'),
                             ('volumes', {}), ('running_images', {'api': 'tag:latest'}),
                             ('sources', {'api': PRIOR, 'web': SHA})]:
            value_ = fixture(); value_[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): self.validate(value_)

    def test_unexpected_fields_duplicate_keys_or_private_response_are_not_republished(self):
        value=fixture(); value['private']='body-canary'
        for raw in (json.dumps(value).encode(), b'not-json-canary', b'{"status":"PASS","status":"FAIL"}'):
            with self.subTest(raw=raw[:20]), self.assertRaises(ValueError) as error:
                readback_contract.validate(raw, SHA, CONTROLLER, PRIOR, NONCE)
            self.assertNotIn('canary', str(error.exception))

    def test_observed_or_explicit_legacy_rollout_intervals_are_validated(self):
        from tools.release.install import timings
        measured=timings.parse(''.join(f'{name} {1000+i}\n' for i,name in enumerate(timings.ORDER)))
        for rollout in (measured,{'status':'NOT_AVAILABLE_LEGACY','events':[]}):
            value=fixture();value['rollout']=rollout
            self.assertEqual(rollout,self.validate(value)['rollout'])
        value=fixture();value['rollout']={**measured,'private':'private-canary'}
        with self.assertRaises(ValueError):self.validate(value)
