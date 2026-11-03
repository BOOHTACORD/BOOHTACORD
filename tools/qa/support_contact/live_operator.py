"""Explicit opt-in synthetic live GitHub proof, never called by ordinary CI."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

def main():
    marker=sys.argv[1];phase=sys.argv[2] if len(sys.argv)>2 else 'reply'
    if not re.fullmatch('Synthetic BOOHTACORD public bridge QA [a-f0-9]{16}',marker) or phase not in {'reply','followup','close'}:
        raise ValueError('Only the fixed synthetic public proof is allowed')
    config=json.loads(Path(os.environ['BOOHTACORD_SUPPORT_QA_OPERATOR']).read_text())
    wait=int(os.environ.get('BOOHTACORD_SUPPORT_PROOF_WAIT','0'))
    if not 0<=wait<=240:raise ValueError('Invalid bounded proof wait')
    if config['host']!='root@167.233.56.32':raise ValueError('Select the existing support gateway operator')
    args=['ssh','-F','/dev/null','-i',config['identity'],'-o','IdentitiesOnly=yes','-o','BatchMode=yes',
          '-o','ConnectTimeout=8','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+config['known_hosts'],config['host'],'python3 -']
    if config.get('control_path'):
        args[1:1]=['-o','ControlMaster=auto','-o','ControlPersist=60','-o','ControlPath='+config['control_path']]
    script='''import hashlib,json,re,sqlite3,subprocess,sys,time,urllib.request
marker=MARKER;phase=PHASE;deadline=time.monotonic()+WAIT
db=sqlite3.connect('/var/lib/boohtacord-support/routing.sqlite')
while True:
 row=db.execute("SELECT issue FROM jobs WHERE state='published' AND json_extract(payload,'$.body')=?",(marker+(' follow-up' if phase=='followup' else ''),)).fetchone()
 if row or time.monotonic()>=deadline:break
 time.sleep(2)
if not row:sys.exit(75)
issue=row[0];repo='repos/BOOHTACORD/BOOHTACORD'
def api(path,method='GET',data=None):
 args=['gh','api',path,'--method',method]
 if data is not None:args+=['--input','-']
 result=subprocess.run(args,input=json.dumps(data).encode() if data is not None else None,capture_output=True,check=True,timeout=30)
 return json.loads(result.stdout)
if phase=='close':
 api(f'{repo}/issues/{issue}','PATCH',{'state':'closed'});print(json.dumps({'issue':issue,'closed':True}));sys.exit(0)
result={'issue':issue}
if phase=='reply':
 text='Synthetic BOOHTACORD public bridge operator reply'
 comments=api(f'{repo}/issues/{issue}/comments?per_page=100')
 if not any(x.get('body')==text for x in comments):api(f'{repo}/issues/{issue}/comments','POST',{'body':text})
 body=api(f'{repo}/issues/{issue}')['body']
 urls=re.findall(r'https://github.com/BOOHTACORD/BOOHTACORD/releases/download/boohtacord-support-attachments/[^)\\s]+',body)
 assert len(urls)==1
 with urllib.request.urlopen(urls[0],timeout=20) as response:content=response.read(1000)
 assert content==b'Synthetic public support QA file\\n'
 result['public_file_verified']=True
print(json.dumps(result))
'''.replace('MARKER',repr(marker)).replace('PHASE',repr(phase)).replace('WAIT',str(wait))
    for _ in range(15):
        result=subprocess.run(args,input=script.encode(),capture_output=True,timeout=wait+50)
        if result.returncode==0:
            print(json.dumps(json.loads(result.stdout)));return
        if result.returncode!=75:raise RuntimeError('Controlled live operator proof failed; no provider payload logged')
        time.sleep(2)
    raise RuntimeError('Controlled support publication did not become ready')

if __name__=='__main__':main()
