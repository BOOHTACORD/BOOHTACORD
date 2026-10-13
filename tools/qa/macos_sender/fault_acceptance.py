"""Actual isolated metadata recovery proof; never substitutes configuration readiness."""
def fault_events(events):
 markers=[i for i,e in enumerate(events)if e.get('event')=='isolated_metadata_fault_mode_change']
 return events[markers[-1]+1:]if markers else []
def failed(event):
 return event.get('event')=='descriptor_http_response'and event.get('status')==503 or event.get('event')=='descriptor_http_error'and event.get('error_type')in('TimeoutException','RequestAbortedException')
def recovery_due(events):
 rows=fault_events(events)
 return sum(failed(e)for e in rows)>=2 and any(e.get('event')=='descriptor_state'and e.get('writer_status')=='unavailable'for e in rows)
def require_metadata_recovery(events,mode):
 rows=fault_events(events)
 if mode not in ('failure','slow')or not recovery_due(events):raise ValueError('Actual isolated retryable failure proof required')
 requests=[];current=None
 for e in rows:
  if e.get('event')=='descriptor_http_start':current=e
  elif e.get('event')in('descriptor_http_response','descriptor_http_error')and current is not None:
   requests.append((current,e));current=None
 failures=[(s,e)for s,e in requests if failed(e)]
 successful=[(s,e)for s,e in requests if e.get('status')==204 and s.get('mode')=='text']
 if len(failures)<2 or not successful:raise ValueError('Actual failed wave and successful identical retry required')
 seed=failures[-1][0];applied=successful[0][0]
 if applied.get('same_body_as_previous')is not True or failures[-1][0].get('same_body_as_previous')is not True or any(applied.get(k)!=seed.get(k)for k in('publication_generation','operation_revision')):raise ValueError('Recovery changed failed body/publication/operation')
 if not any(e.get('event')=='descriptor_state'and e.get('writer_status')=='applied'and e.get('applied_ack_present')is True and e.get('publication_generation')==seed.get('publication_generation')for e in rows):raise ValueError('Fresh recovered ACK required')
 accepted=[e.get('accepted_frames')for e in rows if e.get('event')=='native_capture_sample'and isinstance(e.get('accepted_frames'),int)]
 if len(accepted)<2 or accepted[-1]<=accepted[0]:raise ValueError('Capture did not continue across fault')
 idle=[e for e in rows if e.get('event')=='post_stop_idle'];stopped=[e for e in rows if e.get('event')=='publication_stopped']
 if not idle or idle[-1].get('new_reports')!=0 or idle[-1].get('pending_descriptors')!=0 or not stopped or stopped[-1].get('maximum_pending_descriptors')!=1:raise ValueError('Bounded writer/stop idle required')
 return {'actual_failed_attempts':len(failures),'actual_recovery_http_status':204,'same_failed_payload_and_operation_recovered':True,'publication_generation_unchanged':True,'capture_progressed':True,'stop_idle_no_new_sender_reports':True,'maximum_pending_descriptors':1,'scope':'Isolated proxy metadata fault, not a Go authorization failure'}
