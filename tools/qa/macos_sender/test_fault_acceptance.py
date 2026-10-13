import unittest
from .fault_acceptance import recovery_due,require_metadata_recovery
class FaultAcceptanceTests(unittest.TestCase):
 def test_requires_actual_two_failed_attempts_unavailable_stable_body_and_same_generation_recovery(self):
  start=lambda same:{'event':'descriptor_http_start','mode':'text','publication_generation':1,'operation_revision':3,'same_body_as_previous':same}
  events=[{'event':'isolated_metadata_fault_mode_change'},start(False),{'event':'descriptor_http_response','status':503},start(True),{'event':'descriptor_http_response','status':503},{'event':'descriptor_state','writer_status':'unavailable'}]
  self.assertTrue(recovery_due(events));self.assertFalse(recovery_due(events[:-1]))
  events +=[start(True),{'event':'descriptor_http_response','status':204},{'event':'descriptor_state','writer_status':'applied','publication_generation':1,'applied_ack_present':True},{'event':'native_capture_sample','accepted_frames':12},{'event':'native_capture_sample','accepted_frames':25},{'event':'publication_stopped','maximum_pending_descriptors':1,'pending_descriptors':0},{'event':'post_stop_idle','new_reports':0,'pending_descriptors':0}]
  self.assertTrue(require_metadata_recovery(events,'failure')['same_failed_payload_and_operation_recovered'])
  for changes in [('same_body_as_previous',False),('publication_generation',2)]:
   rows=[dict(e)for e in events];rows[6][changes[0]]=changes[1]
   with self.assertRaises(ValueError):require_metadata_recovery(rows,'failure')
  with self.assertRaises(ValueError):require_metadata_recovery([e for e in events if e.get('status')!=503],'failure')
