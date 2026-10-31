"""Require exact native Caddy and execute real HTTP1 upload response regression."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[3]

def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--caddy',type=Path,required=True)
 parser.add_argument('--sha256',required=True)
 parser.add_argument('--output',type=Path,required=True)
 args=parser.parse_args()
 if sys.platform!='linux':raise SystemExit('Native Linux fixture required; never skip missing Caddy')
 if not re.fullmatch('[a-f0-9]{64}',args.sha256):raise SystemExit('Exact Caddy SHA256 is mandatory')
 binary=args.caddy.resolve()
 if hashlib.sha256(binary.read_bytes()).hexdigest()!=args.sha256:raise SystemExit('Caddy digest differs')
 version=subprocess.check_output(['go','version'],text=True).strip()
 if not version.startswith('go version go1.26.4 '):raise SystemExit('Pinned Go1.26.4 is required')
 args.output.mkdir(parents=True,exist_ok=True)
 sources=sorted(Path(__file__).parent.glob('*_test.go'))
 environment=dict(os.environ,BOOHTACORD_QA_CADDY_BIN=str(binary),BOOHTACORD_QA_CADDY_SHA=args.sha256,BOOHTACORD_QA_CADDYFILE=str(ROOT/'deploy/caddy/Caddyfile'))
 log=args.output/'native-caddy-test.log'
 with tempfile.TemporaryDirectory(prefix='boohtacord-upload-proxy-') as directory:
  overlay=Path(directory)/'overlay.json'
  mapping={str(ROOT/'backend/internal/storage/upload_request'/('qa_proxy_'+source.name)):str(source.resolve()) for source in sources}
  overlay.write_text(json.dumps({'Replace':mapping}),encoding='utf-8')
  command=['go','test','-overlay',str(overlay),'./internal/storage/upload_request','-run','^TestCaddyProxy','-count=1','-timeout=30s','-v']
  with log.open('wb') as stream:result=subprocess.run(command,cwd=ROOT/'backend',env=environment,stdout=stream,stderr=subprocess.STDOUT)
 text=log.read_text(encoding='utf-8')
 receipt={'kind':'native-pinned-caddy-upload-proxy-regression','status':'PASS' if result.returncode==0 else 'FAIL','exit_code':result.returncode,'Go':version,'Caddy':'v2.10.0','Caddy_binary_SHA256':args.sha256,'production_Caddyfile_Git_LF_SHA256':hashlib.sha256((ROOT/'deploy/caddy/Caddyfile').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'test_source_SHA256':{source.name:hashlib.sha256(source.read_bytes()).hexdigest() for source in sources},'log_SHA256':hashlib.sha256(log.read_bytes()).hexdigest(),'passed_events':len(re.findall(r'^\s*--- PASS:',text,re.M)),'failed_events':len(re.findall(r'^\s*--- FAIL:',text,re.M)),'skipped_events':len(re.findall(r'^\s*--- SKIP:',text,re.M)),'scope':'Owned loopback HTTP1 native Caddy/Go fixtures, admin and TLS disabled, isolated XDG/temp state; no MAIN service/profile/CA/accounts','limits':'Scaled40ms idle/300ms maximum; not real60s/900s TLS acceptance'}
 (args.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(receipt))
 if receipt['skipped_events']:raise SystemExit('Skipped native fixture is never accepted')
 raise SystemExit(result.returncode)

if __name__=='__main__':main()
