"""Own actual PostgreSQL/Go/LiveKit fixture. Private secrets never enter receipt."""
import json,os,subprocess,tempfile,time,hashlib
from pathlib import Path
from datetime import datetime,timezone
from tools.qa.mini_player.native import source_manifest
from .stack import Stack

def main():
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa272-20261013';out.mkdir(parents=True,exist_ok=True);receipt=out/'fixture-runtime.json'
 report={'issue':272,'status':'RUNNING','candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'backend_source_sha256':source_manifest(root/'backend')[0],'scope':'actual secure API/SFU fixture; no fabricated API or transport','started_at':datetime.now(timezone.utc).isoformat()}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 with tempfile.TemporaryDirectory(prefix='qa272-',dir=root/'.out') as temp:
  stack=Stack(root,Path(temp))
  try:
   stack.start();assert report['backend_source_sha256']==source_manifest(root/'backend')[0]
   image_names=[stack.image,'postgres:17.6-alpine','caddy:2.10.0-alpine','grafana/tempo:2.10.3']
   from tools.audio.livekit_fixture import IMAGE
   image_names.append(IMAGE)
   report['image_ids']={('api' if n==stack.image else n):subprocess.check_output(['docker','image','inspect',n,'--format','{{.Id}}'],text=True).strip() for n in image_names};report['phase']='API_BUILD_DONE';save();print('API_BUILD_DONE',flush=True)
   inputs=Path(temp)/'input.json';inputs.write_text(json.dumps({'password':stack.password,'directory':str(out/'web'),'owner':stack.owner}));inputs.chmod(0o600);(out/'active-input-path').write_text(str(inputs))
   subprocess.run(['node',str(root/'tools/qa/roster_runtime/seed.mjs')],cwd=root,env=dict(os.environ,QA_INPUT=str(inputs)),check=True,timeout=90)
   inputs.chmod(0o600);report['status']='READY';save();print('Owned roster fixture READY',flush=True)
   while not Path('/private/tmp/qa272-release').exists():time.sleep(.5)
  except BaseException as e:report.update(status='FAIL',error_type=type(e).__name__);raise
  finally:
   stack.close();(out/'active-input-path').unlink(missing_ok=True);report['owned_resources_removed']=True;report['completed_at']=datetime.now(timezone.utc).isoformat();save()

if __name__=='__main__':main()
