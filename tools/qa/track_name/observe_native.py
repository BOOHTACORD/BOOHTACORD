"""Read authorized private Mac fixture input; own headless observer/server only."""
import argparse,hashlib,json,os,subprocess,time,urllib.request
from pathlib import Path
from datetime import datetime,timezone
from tools.qa.dm_composer.integrity import archive_previous
from tools.qa.client_lifecycle.services import ports_available
from .run import manifest,digest

def main():
 p=argparse.ArgumentParser();p.add_argument('--private-input',type=Path,required=True);a=p.parse_args()
 if a.private_input.stat().st_mode&0o077:raise ValueError('Private input must be owner-only')
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa327-native-observer';out.mkdir(parents=True,exist_ok=True);archive_previous(out);source=manifest(root/'clients/web/src')
 report={'status':'RUNNING','candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'started_at':datetime.now(timezone.utc).isoformat(),'web_source_manifest_sha256':hashlib.sha256(json.dumps(source,sort_keys=True).encode()).hexdigest(),'qa_handler_sha256':{f:digest(root/'tools/qa/track_name'/f)for f in ['observe_native.py','observe_native.mjs']},'owned_observer_resources_removed':False};receipt=out/'runtime.json'
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();server=None
 try:
  ports_available((5087,))
  with (out/'private-server.log').open('w')as log:
   server=subprocess.Popen(['node','node_modules/vite/bin/vite.js','--host','127.0.0.1','--port','5087','--strictPort'],cwd=root/'clients/web',stdout=log,stderr=log,start_new_session=True)
   for _ in range(100):
    try:
     with urllib.request.urlopen('http://127.0.0.1:5087/tests/track_name/fixture.html',timeout=1)as response:
      if response.status==200:break
    except OSError:time.sleep(.1)
   else:raise RuntimeError('Observer fixture not ready')
   subprocess.run(['node',str(root/'tools/qa/track_name/observe_native.mjs')],cwd=root,env=dict(os.environ,QA_NATIVE_PRIVATE_INPUT=str(a.private_input),QA_NATIVE_OUT=str(out)),check=True,timeout=240)
  scenario=json.loads((out/'scenario.json').read_text())
  if scenario.get('status')!='PASS' or len(scenario.get('checks',{}))!=5 or any(v!='PASS'for v in scenario['checks'].values()):raise RuntimeError('Observer rows incomplete')
  if manifest(root/'clients/web/src')!=source:raise RuntimeError('Observer source changed')
  report.update(scenario)
 except Exception as e:
  if(out/'scenario.json').exists():report.update(json.loads((out/'scenario.json').read_text()))
  report.update(status='FAIL',runner_error_type=type(e).__name__);raise
 finally:
  if server is not None and server.poll()is None:
   server.terminate()
   try:server.wait(timeout=10)
   except subprocess.TimeoutExpired:server.kill();server.wait()
  report.update(owned_observer_resources_removed=True,completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:digest(p)for p in out.glob('*.png')});save()
 print('#327 physical native→headless source-module observer correctness PASS; FPS/quality NOT_RUN',flush=True)
if __name__=='__main__':main()
