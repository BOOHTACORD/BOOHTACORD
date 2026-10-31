"""Extract a pinned binary without starting a container; remove only owned state."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

LABEL='boohtacord.qa.upload-proxy'

def docker(*args,check=True,timeout=30):
 result=subprocess.run(['docker',*args],capture_output=True,text=True,timeout=timeout)
 if check and result.returncode:
  print(result.stderr[:2000],file=sys.stderr)
  result.check_returncode()
 return result

class NativeImage:
 def __init__(self,pin,directory,owner):
  if not re.fullmatch('[a-z0-9-]{1,50}',owner):raise ValueError('Unsafe native fixture owner')
  if not re.fullmatch('caddy@sha256:[a-f0-9]{64}',pin['image']) or pin['repo_digest']!=pin['image']:
   raise ValueError('Immutable approved Caddy image digest required')
  if pin['platform']!='linux/amd64' or pin['binary']!='/usr/bin/caddy' or not re.fullmatch('[a-f0-9]{64}',pin['binary_sha256']):
   raise ValueError('Declared Caddy platform/path/binary digest differs')
  self.pin,self.directory,self.owner=pin,Path(directory),owner
  self.name='boohta-upload-proxy-'+owner
  self.identifier=None

 def owned(self):
  result=docker('inspect',self.identifier or self.name,check=False)
  if result.returncode:
   if result.returncode==1 and 'no such' in result.stderr.lower():return None
   raise RuntimeError('Cannot establish owned native extraction container identity')
  rows=json.loads(result.stdout)
  if len(rows)!=1:raise RuntimeError('Ambiguous native extraction container')
  row=rows[0]
  valid=(row['Name'].lstrip('/')==self.name and row['Config']['Labels'].get(LABEL)==self.owner
         and row['Config']['Image']==self.pin['image'] and row['State']['Running'] is False
         and re.fullmatch('[a-f0-9]{64}',row['Id']))
  if not valid or self.identifier and row['Id']!=self.identifier:
   raise RuntimeError('Native extraction ownership/image/running guard rejected action')
  return row

 def extract(self):
  result=docker('create','--platform',self.pin['platform'],'--network','none','--read-only',
                '--name',self.name,'--label',LABEL+'='+self.owner,
                '--entrypoint',self.pin['binary'],self.pin['image'],'version',timeout=180)
  identifier=result.stdout.strip()
  if not re.fullmatch('[a-f0-9]{64}',identifier):raise RuntimeError('Invalid created container identity')
  self.identifier=identifier
  if self.owned() is None:raise RuntimeError('Created native extraction container vanished')
  images=json.loads(docker('image','inspect',self.pin['image']).stdout)
  digests=[value.removeprefix('docker.io/library/') for value in images[0].get('RepoDigests',[])]
  if self.pin['repo_digest'] not in digests:raise RuntimeError('Native Caddy manifest digest differs')
  self.directory.mkdir(parents=True,exist_ok=True)
  binary=self.directory/'caddy'
  docker('cp',identifier+':'+self.pin['binary'],str(binary))
  if binary.stat().st_size>self.pin['max_binary_bytes'] or hashlib.sha256(binary.read_bytes()).hexdigest()!=self.pin['binary_sha256']:
   raise RuntimeError('Native Caddy binary digest/size differs')
  return binary

 def cleanup(self):
  row=self.owned()
  if row is not None:
   docker('rm',row['Id'])
   if self.owned() is not None:raise RuntimeError('Owned native extraction container survived cleanup')
  return True
