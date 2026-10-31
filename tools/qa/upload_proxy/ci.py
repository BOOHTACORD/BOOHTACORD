"""Mandatory source-bound hosted CI wrapper for the real Caddy regression."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import uuid
from .image import NativeImage,docker

ROOT=Path(__file__).resolve().parents[3]

def source():
 revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 if os.environ.get('GITHUB_SHA')!=revision:raise RuntimeError('Native proxy CI checkout differs from event source')
 subprocess.run(['git','diff','--exit-code','HEAD','--'],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
 return revision

def native_check(pin,destination,owner,record):
 with tempfile.TemporaryDirectory(prefix='boohta-caddy-extract-') as directory:
  image=NativeImage(pin,directory,owner)
  record['owned_container_cleanup_verified']=False
  try:
   binary=image.extract()
   info=subprocess.check_output(['go','version','-m',str(binary)],text=True)
   if info.splitlines()[0].split()[-1]!=pin['embedded_go']:raise RuntimeError('Embedded native Caddy Go version differs')
   record['native_embedded_Go']=pin['embedded_go']
   command=[sys.executable,'-m','tools.qa.upload_proxy.run','--caddy',str(binary),'--sha256',pin['binary_sha256'],'--output',str(destination/'native')]
   result=subprocess.run(command,cwd=ROOT,timeout=180)
   record['native_exit_code']=result.returncode
   if result.returncode:raise RuntimeError('Native Caddy upload proxy regression failed')
   native=json.loads((destination/'native/receipt.json').read_text())
   if (native['status']!='PASS' or native['passed_events']!=12 or native['failed_events']!=0
       or native['skipped_events']!=0 or native['Caddy_binary_SHA256']!=pin['binary_sha256']):
    raise RuntimeError('Native Caddy result failed, skipped or did not execute the complete reviewed suite')
   record['native_result']=native
  finally:
   record['owned_container_cleanup_verified']=image.cleanup()

def main():
 destination=ROOT/'.out/ci/upload-proxy'
 destination.mkdir(parents=True,exist_ok=True)
 record={'status':'FAIL','source_revision':os.environ.get('GITHUB_SHA'),'run_id':os.environ.get('GITHUB_RUN_ID'),'run_attempt':os.environ.get('GITHUB_RUN_ATTEMPT')}
 path=destination/'summary.json'
 path.write_text(json.dumps(record)+'\n',encoding='utf-8')
 try:
  if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux' or platform.machine()!='x86_64':
   raise RuntimeError('This required wrapper runs only on the declared hosted Linux x64 CI worker')
  revision=source()
  pin=json.loads((ROOT/'tools/qa/upload_proxy/pin.json').read_text())
  compose=json.loads(docker('compose','--env-file','.env.example','-f','deploy/compose.yaml','config','--format','json').stdout)
  if compose['services']['proxy']['image']!=pin['compose_image']:raise RuntimeError('Reviewed production Caddy version differs from native test pin')
  owner=str(os.environ['GITHUB_RUN_ID'])+'-'+str(os.environ['GITHUB_RUN_ATTEMPT'])+'-'+uuid.uuid4().hex[:8]
  record['image_ref']=pin['image']
  record['binary_SHA256']=pin['binary_sha256']
  native_check(pin,destination,owner,record)
  if source()!=revision:raise RuntimeError('Native Caddy CI source changed during execution')
  record['status']='PASS'
 except Exception as error:
  record['error_type']=type(error).__name__
  print(str(error),file=sys.stderr)
 finally:
  path.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'status':record['status'],'source_revision':record['source_revision'],'cleanup':record.get('owned_container_cleanup_verified')}))
 return 0 if record['status']=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())
