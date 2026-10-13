"""Pin a compiled browser candidate and observe a completed real roster journey."""
import hashlib,json,os,subprocess,time
from pathlib import Path
from datetime import datetime,timezone
from tools.qa.mini_player.native import source_manifest,archive_previous
REQUIRED=('bounded_auth_database_timeout_503','initial_503_no_false_zero','populated_rest_sse_two_accounts','realtime_mute_screen_share','realtime_peer_join_leave','refresh_failure_no_false_zero_recovery','db_outage_recovery_no_false_zero','network_and_browser_engine_freeze_recovery','guest_member_acl_and_revoked_lease_exclusion','revoked_session_clears_roster','one_healthy_eventsource_no_polling')
def validated(value):
 if value.get('status')!='PASS' or any(value.get('checks',{}).get(k)!='PASS' for k in REQUIRED):raise RuntimeError('Required actual roster scenarios incomplete')
 if value.get('actual_api') is not True or value.get('actual_sfu') is not True or value.get('mocks') is not False:raise RuntimeError('Actual roster transport proof missing')
 if value.get('observer_counters',{}).get('max_active')!=1:raise RuntimeError('Healthy watcher bound missing')
 return value

def main():
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa272-20261013/web';out.mkdir(parents=True,exist_ok=True);archive_previous(out)
 receipt=out/'runtime.json';report={'issue':272,'status':'RUNNING','runtime_completed':False,'started_at':datetime.now(timezone.utc).isoformat(),'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();child=None;os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 try:
  proof=root/'.out/qa272-build-source.json';provenance=json.loads(proof.read_text());assert provenance['status']=='PASS' and source_manifest(root/'.out/qa272-build')[0]==provenance['web_dist_manifest_sha256']
  report.update(build_provenance=provenance,build_provenance_sha256=hashlib.sha256(proof.read_bytes()).hexdigest(),observed_source_sha256=source_manifest(root/'clients/web/src')[0],qa_handler_sha256={n:hashlib.sha256((root/'tools/qa/roster_runtime'/n).read_bytes()).hexdigest()for n in ['run.py','scenario.mjs','control.mjs']});save()
  inputs=Path((out.parent/'active-input-path').read_text());assert json.loads((out.parent/'fixture-runtime.json').read_text())['status']=='READY'
  data=json.loads(inputs.read_text());data['directory']=str(out);inputs.write_text(json.dumps(data));inputs.chmod(0o600)
  with open('/private/tmp/qa272-web-runtime.log','w')as log:
   child=subprocess.Popen(['node',str(root/'tools/qa/roster_runtime/scenario.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:5070',QA_INPUT=str(inputs),QA_RESULT=str(out/'scenario.json')),stdout=log,stderr=subprocess.STDOUT)
   deadline=time.monotonic()+650
   while time.monotonic()<deadline:
    p=out/'scenario.json'
    if p.exists():
     value=json.loads(p.read_text())
     if value.get('status')!='RUNNING':
      if value.get('status')=='FAIL':
       child.wait(timeout=30);report.update(value)
      report.update(validated(value));report['runtime_completed']=True;report['holder_active']=True;save();print('QA272_WEB_PASS_HOLD',flush=True);break
    if child.poll()is not None:raise RuntimeError('Browser stopped before completed scenarios')
    time.sleep(.2)
   else:raise TimeoutError('Actual roster journey deadline')
   code=child.wait(timeout=1800)
   if code:raise RuntimeError('Browser holder failed')
   report['holder_active']=False
 except BaseException as e:
  report.update(status='FAIL',error_type=type(e).__name__)
  if child and child.poll()is None:child.terminate();child.wait(timeout=20)
  raise
 finally:
  report.update(completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in out.glob('*.png')});save()
if __name__=='__main__':main()
