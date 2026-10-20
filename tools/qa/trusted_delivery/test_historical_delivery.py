"""Historical inspection preserves actual timestamps and rejects unrelated ACKs."""
from copy import deepcopy
from datetime import timedelta
import unittest
from .historical_delivery import checked
from .test_evidence import receipt,WINDOW


class HistoricalDeliveryTests(unittest.TestCase):
    def validate(self,row):
        return checked(row['delivery'],nonce=row['attempt_nonce'],observed_at=row['acknowledged_at'],window=WINDOW)

    def test_reads_recorded_receipt_without_rewriting_any_timestamp_or_payload(self):
        row=receipt()['installations'][0];original=deepcopy(row)
        self.assertEqual(original['delivery'],self.validate(row))
        self.assertEqual(original,row)

    def test_rejects_incomplete_private_mismatched_or_non_finite_records(self):
        for mode in ('phase_missing','phase_duplicate','phase_limit','phase_failure','phase_nan','ack_private',
                     'ack_version','ack_sources','ack_volumes','ack_image','ack_kind','ack_schema','timestamp'):
            row=receipt()['installations'][0];value=row['delivery'];ack=value['readback']
            if mode=='phase_missing':value['phases'].pop()
            if mode=='phase_duplicate':value['phases'][1]=value['phases'][0]
            if mode=='phase_limit':value['phases'][0]['limit_seconds']=True
            if mode=='phase_failure':value['phases'][0]['failure_code']='timeout'
            if mode=='phase_nan':value['phases'][0]['elapsed_seconds']=float('nan')
            if mode=='ack_private':ack['cookie']='private-canary'
            if mode=='ack_version':ack['schema_version']=True
            if mode=='ack_sources':ack['sources']['api']='0'*40
            if mode=='ack_volumes':ack['volumes']={}
            if mode=='ack_image':ack['running_images']['web']='image:mutable'
            if mode=='ack_kind':ack['kind']='unverified'
            if mode=='ack_schema':ack['schema_relation']='unknown'
            if mode=='timestamp':ack['checked_at']='private-canary'
            with self.subTest(mode=mode),self.assertRaises(ValueError) as error:self.validate(row)
            self.assertNotIn('private-canary',str(error.exception))
        row=receipt()['installations'][0]
        with self.assertRaises(ValueError):
            checked(row['delivery'],nonce=row['attempt_nonce'],observed_at=row['acknowledged_at'],
                    window=(WINDOW[0],WINDOW[1]+timedelta(hours=1)))
