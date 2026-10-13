"""Owned actual Go/SFU peer integration; preserves failed attempts and measured source."""
import hashlib,json,os,subprocess,tempfile,time,urllib.request
from pathlib import Path
from datetime import datetime,timezone
from .stack import Stack
from tools.qa.dm_composer.integrity import archive_previous
REQUIRED=('real_SDK_native_style_name_without_descriptor','no_screen_subscription_before_choice','one_selected_renderer_no_repeat_subscription','honest_legacy_startup_UI','reconnect_retains_profile_and_requires_choice','unpublish_republish_replaces_profile','unknown_name_no_invented_target','actual_peer_leave_and_voice_lease_cleanup')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def manifest(p):return {str(q.relative_to(p)):digest(q) for q in sorted(p.rglob('*')) if q.is_file()}
def main():
 root=Path(__file__).resolve().parents[3];os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa';out=root/'.out/qa327-20261013';out.mkdir(parents=True,exist_ok=True);archive_previous(out)
 selected=manifest(root/'clients/web/src');receipt=out/'runtime.json'
 report={'issue':327,'status':'RUNNING','candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'started_at':datetime.now(timezone.utc).isoformat(),'web_source_manifest_sha256':hashlib.sha256(json.dumps(selected,sort_keys=True).encode()).hexdigest(),'qa_files':{str(q.relative_to(root)):digest(q) for directory in [root/'tools/qa/track_name',root/'clients/web/tests/track_name'] for q in directory.rglob('*') if q.is_file() and q.suffix in ('.py','.mjs','.md','.html','.ts')},'SDK_version':json.loads((root/'clients/web/node_modules/livekit-client/package.json').read_text())['version'],'scope':'Actual pinned SDK publishing peer and production registry/controller/diagnostics UI via Vite; actual secure-cookie Go API and SFU. Synthetic640x360/15 source, profile name1080p60 only launch intent. No physical performance claim.','owned_cleanup':False}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();stack=None;vite=None
 try:
  with tempfile.TemporaryDirectory(prefix='qa327-',dir=root/'.out')as temp:
   work=Path(temp);stack=Stack(root,work);stack.start();report.update(backend_source_manifest_sha256=stack.backend_source_manifest_sha256,backend_image_id=stack.backend_image_id);save()
   log=work/'vite.log'
   with log.open('w')as output:
    vite=subprocess.Popen(['node','node_modules/vite/bin/vite.js','--host','127.0.0.1','--port','5087','--strictPort'],cwd=root/'clients/web',stdout=output,stderr=output,start_new_session=True)
    for _ in range(100):
     if vite.poll()is not None:raise RuntimeError('Own fixture server terminated')
     try:
      with urllib.request.urlopen('http://127.0.0.1:5087/tests/track_name/fixture.html',timeout=1)as r:
       if r.status==200:break
     except OSError:time.sleep(.1)
    else:raise RuntimeError('Own fixture server not ready')
    inp=work/'input.json';inp.write_text(json.dumps({'password':stack.password,'directory':str(out)}));inp.chmod(0o600)
    subprocess.run(['node',str(root/'tools/qa/track_name/scenario.mjs')],cwd=root,env=dict(os.environ,QA_INPUT=str(inp),QA_RESULT=str(out/'scenario.json')),check=True,timeout=420)
   scenario=json.loads((out/'scenario.json').read_text())
   if scenario.get('status')!='PASS' or any(scenario.get('checks',{}).get(k)!='PASS'for k in REQUIRED):raise RuntimeError('Required actual runtime rows missing')
   if len(list(out.glob('*.png')))!=3:raise RuntimeError('Required original captures missing')
   if manifest(root/'clients/web/src')!=selected:raise RuntimeError('Runtime Web source changed during run')
   report.update(scenario)
 except Exception as error:
  if(out/'scenario.json').exists():report.update(json.loads((out/'scenario.json').read_text()))
  report.update(status='FAIL',runner_error_type=type(error).__name__);raise
 finally:
  if vite is not None and vite.poll()is None:
   vite.terminate()
   try:vite.wait(timeout=10)
   except subprocess.TimeoutExpired:vite.kill();vite.wait()
  if stack is not None:stack.close()
  report.update(owned_cleanup=True,completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:digest(p)for p in out.glob('*.png')});save()
 print('#327 actual SDK/Go/SFU correctness PASS; physical hardware NOT_RUN',flush=True)
if __name__=='__main__':main()
