import unittest,json
from .stage_baseline import case_plan, archive_previous, require_built_proof, owned_viewer_registered,receipt_output
from pathlib import Path
import tempfile
class StagePlanTests(unittest.TestCase):
 def test_profiles_are_explicit_and_bounded(self):
  self.assertEqual(case_plan(2),{'resolution':1080,'fps':60,'static':False})
  self.assertEqual(case_plan(4)['resolution'],720)
  self.assertEqual(case_plan(5)['fps'],30)
  self.assertTrue(case_plan(6)['static'])
  self.assertEqual(case_plan(13)['resolution'],720)
  self.assertTrue(case_plan(11)['static'])
  for index in (0,21,99):
   with self.assertRaises(ValueError):case_plan(index)
 def test_archive_removes_stale_ready_and_result(self):
  with tempfile.TemporaryDirectory() as directory:
   out=Path(directory)
   for name in ('receiver-2-ready.json','receiver-2.json','codec-negotiation-2.json','healthy-2.json','restart-2.json'): (out/name).write_text('old')
   archive_previous(out,2)
   self.assertFalse((out/'receiver-2-ready.json').exists())
   self.assertFalse((out/'codec-negotiation-2.json').exists())
   self.assertFalse((out/'healthy-2.json').exists())
   self.assertFalse((out/'restart-2.json').exists())
   self.assertEqual(len(list((out/'previous').rglob('receiver-2.json'))),1)

 def test_failed_build_or_old_binary_cannot_produce_new_measurement_pass(self):
  import hashlib
  with tempfile.TemporaryDirectory() as d:
   work=Path(d);binary=work/'flutter/build/macos/Build/Products/Debug/BOOHTACORD.app/Contents/MacOS/BOOHTACORD';binary.parent.mkdir(parents=True);binary.write_bytes(b'binary')
   from .run import bundle_manifest
   proof={'status':'BUILT','artifact_sha256':hashlib.sha256(b'binary').hexdigest(),'app_bundle_manifest_sha256':bundle_manifest(binary.parent.parent.parent)};require_built_proof(work,proof)
   for bad in ({**proof,'status':'FAIL'},{**proof,'artifact_sha256':'0'*64}):
    with self.assertRaises(ValueError):require_built_proof(work,bad)

 def test_registration_skips_only_same_owned_case_with_fresh_prior_readiness(self):
  import json
  with tempfile.TemporaryDirectory()as d:
   out=Path(d);self.assertFalse(owned_viewer_registered(out,13))
   p=out/'receiver-13-ready.json';p.write_text(json.dumps({'case':12,'ready':True}));self.assertFalse(owned_viewer_registered(out,13))
   p.write_text(json.dumps({'case':13,'ready':True}));self.assertTrue(owned_viewer_registered(out,13))
   archive_previous(out,13);self.assertTrue(owned_viewer_registered(out,13));self.assertFalse(owned_viewer_registered(out,14))

 def test_old_dart_bundle_is_rejected_even_with_identical_macos_launcher(self):
  from .run import bundle_manifest
  import hashlib
  with tempfile.TemporaryDirectory()as d:
   work=Path(d);app=work/'flutter/build/macos/Build/Products/Debug/BOOHTACORD.app';binary=app/'Contents/MacOS/BOOHTACORD';binary.parent.mkdir(parents=True);binary.write_bytes(b'same launcher');kernel=app/'Contents/Resources/kernel_blob.bin';kernel.parent.mkdir();kernel.write_bytes(b'old Dart')
   proof={'status':'BUILT','artifact_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'app_bundle_manifest_sha256':bundle_manifest(app)};require_built_proof(work,proof)
   kernel.write_bytes(b'new Dart')
   with self.assertRaises(ValueError):require_built_proof(work,proof)

 def test_existing_fixture_fact_requires_owned_database_verification_not_fake_media_readiness(self):
  with tempfile.TemporaryDirectory()as d:
   out=Path(d);p=out/'receiver-15-owned-fixture.json';p.write_text(json.dumps({'case':15,'fixture_present_in_owned_DB':True,'owned_DB_label_verified':False}));self.assertFalse(owned_viewer_registered(out,15))
   p.write_text(json.dumps({'case':15,'fixture_present_in_owned_DB':True,'owned_DB_label_verified':True}));self.assertTrue(owned_viewer_registered(out,15));self.assertFalse(owned_viewer_registered(out,14))

 def test_receipt_scope_preserves_historical_rows_without_escaping_owned_output(self):
  with tempfile.TemporaryDirectory()as d:
   root=Path(d);self.assertEqual(receipt_output(root,None),root);self.assertEqual(receipt_output(root,'metadata-slow'),root/'metadata-slow')
   for invalid in ['../other','/tmp','anything']:
    with self.assertRaises(ValueError):receipt_output(root,invalid)

 def test_unsigned_release_requires_its_own_whole_bundle_proof(self):
  from .run import bundle_manifest
  with tempfile.TemporaryDirectory()as d:
   work=Path(d);app=work/'flutter/build/macos/Build/Products/Release/BOOHTACORD.app';binary=app/'Contents/MacOS/BOOHTACORD';binary.parent.mkdir(parents=True);binary.write_bytes(b'release')
   import hashlib
   proof={'status':'BUILT','artifact_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'app_bundle_manifest_sha256':bundle_manifest(app)};require_built_proof(work,proof,'release')
   with self.assertRaises(ValueError):require_built_proof(work,proof,'debug')
   with self.assertRaises(ValueError):require_built_proof(work,proof,'../../primary')
