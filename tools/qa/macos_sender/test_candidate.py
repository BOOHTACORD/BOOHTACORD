import unittest,tempfile,json,hashlib
from pathlib import Path
from .candidate import verify_files, codec_caps_document, codec_environment, completed_build_receipt
class CandidateFreezeTests(unittest.TestCase):
 def test_manifest_hashes_source_before_copy_and_rejects_escape(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);(root/'a.dart').write_text('a');digest=hashlib.sha256(b'a').hexdigest()
   verify_files(root,{'a.dart':digest})
   for files in ({'../a.dart':digest},{'a.dart':'0'*64}):
    with self.assertRaises(ValueError):verify_files(root,files)

 def test_measured_receiver_input_uses_adapter_version_contract(self):
  data=codec_caps_document([{'mimeType':'video/VP8','clockRate':90000,'fmtp':[]}])
  self.assertEqual(data['schema_version'],1);self.assertTrue(data['measured']);self.assertEqual(data['receiver_capabilities'][0][0]['sdpFmtpLine'],'')

 def test_caps_environment_is_bound_to_canonical_marked_private_actual_input(self):
  import base64
  with tempfile.TemporaryDirectory()as d:
   work=Path(d);(work/'.qa98325-owned').write_text('owned physical Mac QA\n');caps=work/'codec-receivers-private.json';caps.write_text(json.dumps(codec_caps_document([{'mimeType':'video/VP8','clockRate':90000,'fmtp':[]}])));caps.chmod(0o600)
   env=codec_environment(work);payload=base64.b64decode(env['QA_NATIVE_CODEC_CAPS_B64']);self.assertEqual(hashlib.sha256(payload).hexdigest(),env['QA_NATIVE_CODEC_CAPS_SHA256']);value=json.loads(payload);self.assertEqual(value['ownership_proof']['source_caps_sha256'],hashlib.sha256(caps.read_bytes()).hexdigest());self.assertEqual(set(value['receiver_capabilities'][0][0]),{'mimeType','clockRate','sdpFmtpLine'})
   caps.chmod(0o644)
   with self.assertRaises(ValueError):codec_environment(work)
   caps.chmod(0o600);original=work/'original.json';caps.rename(original);caps.symlink_to(original)
   with self.assertRaises(ValueError):codec_environment(work)

 def test_completed_build_proof_cannot_retain_failed_or_interrupted_current_state(self):
  original={'status':'RUNNING','phase':'BUILDING','no_build_completion_observed':True,'error_type':'CalledProcessError','main_lib_frozen_sha256':'a'*64}
  result=completed_build_receipt(original,'b'*64,'c'*64,{'qa.dart':'d'*64})
  self.assertEqual(result['status'],'BUILT');self.assertNotIn('no_build_completion_observed',result);self.assertNotIn('error_type',result);self.assertTrue(original['no_build_completion_observed']);self.assertEqual(result['app_bundle_manifest_sha256'],'b'*64)
  with self.assertRaises(ValueError):completed_build_receipt({'status':'FAIL'},'b'*64,'c'*64,{})
