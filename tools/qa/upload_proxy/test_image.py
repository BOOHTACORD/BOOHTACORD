"""Owned stopped-container extraction and fail-closed cleanup controls."""
import copy
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import types
import unittest
from unittest.mock import patch
from .image import LABEL,NativeImage

PIN={'image':'caddy@sha256:'+'f'*64,'repo_digest':'caddy@sha256:'+'f'*64,
     'platform':'linux/amd64','binary':'/usr/bin/caddy','binary_sha256':hashlib.sha256(b'native').hexdigest(),'max_binary_bytes':100}

class FakeDocker:
 def __init__(self):
  self.calls=[]
  self.present=False
  self.owner='owner'
  self.running=False
  self.payload=b'native'
 def __call__(self,*args,**options):
  self.calls.append(args)
  value=''
  if args[0]=='create':self.present=True;value='a'*64
  elif args[0]=='inspect':
   if not self.present:return types.SimpleNamespace(returncode=1,stdout='',stderr='No such object')
   value=json.dumps([{'Id':'a'*64,'Name':'/boohta-upload-proxy-owner','Config':{'Labels':{LABEL:self.owner},'Image':PIN['image']},'State':{'Running':self.running}}])
  elif args[:2]==('image','inspect'):value=json.dumps([{'RepoDigests':[PIN['repo_digest']]}])
  elif args[0]=='cp':Path(args[-1]).write_bytes(self.payload)
  elif args[0]=='rm':self.present=False
  else:raise AssertionError(args)
  return types.SimpleNamespace(returncode=0,stdout=value,stderr='')

class ExtractionTests(unittest.TestCase):
 def test_extracts_exact_binary_and_removes_only_created_stopped_container(self):
  fake=FakeDocker()
  with TemporaryDirectory() as directory,patch('tools.qa.upload_proxy.image.docker',fake):
   image=NativeImage(PIN,directory,'owner')
   self.assertEqual(image.extract().read_bytes(),b'native')
   self.assertTrue(image.cleanup())
  self.assertEqual([x for x in fake.calls if x[0]=='rm'],[('rm','a'*64)])
  self.assertFalse(any(x[0] in ('start','run','stop','kill','prune') for x in fake.calls))
 def test_wrong_binary_digest_fails_but_owned_cleanup_is_available(self):
  fake=FakeDocker();fake.payload=b'wrong'
  with TemporaryDirectory() as directory,patch('tools.qa.upload_proxy.image.docker',fake):
   image=NativeImage(PIN,directory,'owner')
   with self.assertRaisesRegex(RuntimeError,'digest'):image.extract()
   self.assertTrue(image.cleanup())
 def test_foreign_or_running_container_is_never_removed(self):
  for owner,running in [('other',False),('owner',True)]:
   with self.subTest(owner=owner,running=running),TemporaryDirectory() as directory:
    fake=FakeDocker();fake.present=True;fake.owner=owner;fake.running=running
    with patch('tools.qa.upload_proxy.image.docker',fake):
     with self.assertRaisesRegex(RuntimeError,'guard'):NativeImage(PIN,directory,'owner').cleanup()
    self.assertFalse(any(x[0]=='rm' for x in fake.calls))
 def test_mutable_image_reference_is_rejected_before_docker(self):
  pin=copy.deepcopy(PIN);pin['image']='caddy:latest'
  with TemporaryDirectory() as directory,patch('tools.qa.upload_proxy.image.docker') as docker:
   with self.assertRaises(ValueError):NativeImage(pin,directory,'owner')
   docker.assert_not_called()

if __name__=='__main__':unittest.main()
