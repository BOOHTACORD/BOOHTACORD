"""Hold the owned actual API fixture; Web login is seeding only, not acceptance."""
import json,os,subprocess,tempfile,time,hashlib
from pathlib import Path
from datetime import datetime,timezone
from tools.qa.mini_player.native import source_manifest
from .stack import Stack

def main():
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa301-20261012';out.mkdir(parents=True,exist_ok=True);receipt=out/'fixture-runtime.json'
 report={'issue':301,'status':'RUNNING','scope':'native actual API/SFU fixture; old Web binary used only for secure login/API seeding, no Web acceptance','old_web_build_manifest':source_manifest(root/'.out/qa301-build')[0],'started_at':datetime.now(timezone.utc).isoformat()}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 with tempfile.TemporaryDirectory(prefix='qa301-',dir=root/'.out') as temp:
  stack=Stack(root,Path(temp))
  try:
   stack.start();inputs=Path(temp)/'input.json';inputs.write_text(json.dumps({'password':stack.password,'directory':str(out/'web'),'owner':stack.owner}));inputs.chmod(0o600);(out/'active-input-path').write_text(str(inputs))
   subprocess.run(['node',str(root/'tools/qa/accessibility_runtime/seed.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:4930',QA_INPUT=str(inputs)),check=True,timeout=90)
   report['status']='READY';save();print('Actual owned API fixture READY',flush=True)
   while not Path('/private/tmp/qa301-release').exists():time.sleep(.5)
  except Exception as e:report.update(status='FAIL',error_type=type(e).__name__);raise
  finally:
   stack.close();(out/'active-input-path').unlink(missing_ok=True);report['owned_resources_removed']=True;report['completed_at']=datetime.now(timezone.utc).isoformat();save()

if __name__=='__main__':main()
