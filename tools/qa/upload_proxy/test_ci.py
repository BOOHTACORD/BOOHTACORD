"""Required CI discovery, failed native runs and cleanup must never become PASS."""
import json
import os
from pathlib import Path
from tempfile import TemporaryDirectory
import types
import unittest
from unittest.mock import patch
from . import ci

class FakeImage:
 def __init__(self,cleanup_error=False):self.cleaned=False;self.cleanup_error=cleanup_error
 def extract(self):return Path('/owned/caddy')
 def cleanup(self):
  self.cleaned=True
  if self.cleanup_error:raise RuntimeError('cleanup failed')
  return True

class RequiredCITests(unittest.TestCase):
 def run_native(self,directory,image,code=0,write=True,passed=12):
  output=Path(directory)
  def native(*args,**kwargs):
   if write:
    (output/'native').mkdir()
    (output/'native/receipt.json').write_text(json.dumps({'status':'PASS','passed_events':passed,'failed_events':0,'skipped_events':0,'Caddy_binary_SHA256':'f'*64}))
   return types.SimpleNamespace(returncode=code)
  record={}
  with patch.object(ci,'NativeImage',return_value=image),patch.object(ci.subprocess,'check_output',return_value='/owned/caddy: go1.24.2\n'),patch.object(ci.subprocess,'run',side_effect=native):
   ci.native_check({'embedded_go':'go1.24.2','binary_sha256':'f'*64},output,'owner',record)
  return record
 def test_success_requires_native_evidence_and_owned_cleanup(self):
  image=FakeImage()
  with TemporaryDirectory() as directory:record=self.run_native(directory,image)
  self.assertTrue(image.cleaned)
  self.assertTrue(record['owned_container_cleanup_verified'])
  self.assertEqual(record['native_exit_code'],0)
 def test_native_failure_and_missing_receipt_still_cleanup(self):
  for code,write in [(1,True),(0,False)]:
   with self.subTest(code=code,write=write),TemporaryDirectory() as directory:
    image=FakeImage()
    with self.assertRaises((RuntimeError,FileNotFoundError)):self.run_native(directory,image,code,write)
    self.assertTrue(image.cleaned)
 def test_cleanup_failure_is_a_gate_failure_even_after_native_success(self):
  with TemporaryDirectory() as directory:
   with self.assertRaisesRegex(RuntimeError,'cleanup failed'):self.run_native(directory,FakeImage(True))
 def test_empty_or_partial_native_suite_is_rejected_and_cleaned(self):
  for passed in (0,11):
   with self.subTest(passed=passed),TemporaryDirectory() as directory:
    image=FakeImage()
    with self.assertRaisesRegex(RuntimeError,'complete reviewed suite'):self.run_native(directory,image,passed=passed)
    self.assertTrue(image.cleaned)
 def test_local_invocation_fails_before_any_docker_action(self):
  with TemporaryDirectory() as directory,patch.object(ci,'ROOT',Path(directory)),patch.dict(os.environ,{'GITHUB_ACTIONS':'false'},clear=True),patch.object(ci,'docker') as docker:
   self.assertEqual(ci.main(),1)
   docker.assert_not_called()
   self.assertEqual(json.loads((Path(directory)/'.out/ci/upload-proxy/summary.json').read_text())['status'],'FAIL')
 def test_required_workflow_step_has_no_optional_skip_or_continue(self):
  text=(ci.ROOT/'.github/workflows/ci-contracts.yaml').read_text()
  block=text.split('      - name: Require native pinned Caddy upload timeout delivery\n',1)[1].split('\n      - name:',1)[0]
  self.assertIn('run: python -m tools.qa.upload_proxy.ci',block)
  self.assertNotIn('if:',block)
  self.assertNotIn('continue-on-error:',block)
  artifact=text.split('      - name: Retain mandatory native upload proxy regression\n',1)[1].split('\n      - name:',1)[0]
  self.assertIn('if: always()',artifact)
  self.assertIn('if-no-files-found: error',artifact)

if __name__=='__main__':unittest.main()
