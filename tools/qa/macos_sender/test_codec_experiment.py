"""Offline experiment gate tests, never media/hardware acceptance."""
import unittest, tempfile, hashlib
from pathlib import Path
from .codec_experiment import alternating_plan,validate_pair,policy_recommendation,controlled_codec,apply_private_codec_overlay
class ExperimentTests(unittest.TestCase):
 def row(self,codec):
  return dict(codec=codec,source_pixels=[1920,1080],capture_path='stabilized-owned-path',capture_diagnostics_enabled=True,profile='1080p60',bitrate_ceiling_bps=8000000,source_manifest='a'*64,sdk_manifest='b'*64,sfu_digest='sha256:'+'c'*64,source_kind='window',source_pattern='fixed-motion-text-geometry-v1',viewer='same-controlled-viewer',network='same-owned-loopback',power='same-power-state',warmup_seconds=30,window_seconds=180,negotiated_codec=codec,encoded_p05_fps=55.0,presented_p05_fps=54.0,hardware_encode=None)
 def test_overlay_rejects_unmarked_copy_and_source_drift_before_write(self):
  with tempfile.TemporaryDirectory()as folder:
   work=Path(folder);flutter=work/'flutter';target=flutter/'lib/src/app/composition/media.dart';target.parent.mkdir(parents=True);target.write_text('original')
   digest=hashlib.sha256(target.read_bytes()).hexdigest()
   with self.assertRaises(ValueError):apply_private_codec_overlay(flutter,digest)
   (work/'.qa98325-owned').write_text('owned physical Mac QA\n')
   with self.assertRaises(ValueError):apply_private_codec_overlay(flutter,'0'*64)
   self.assertEqual(target.read_text(),'original')
 def test_overlay_is_single_guarded_private_media_injection_and_preserves_capture(self):
  with tempfile.TemporaryDirectory()as folder:
   work=Path(folder);(work/'.qa98325-owned').write_text('owned physical Mac QA\n');flutter=work/'flutter';target=flutter/'lib/src/app/composition/media.dart';target.parent.mkdir(parents=True)
   root=Path(__file__).resolve().parents[3];target.write_bytes((root/'clients/flutter/lib/src/app/composition/media.dart').read_bytes());before=hashlib.sha256(target.read_bytes()).hexdigest()
   capture=flutter/'lib/src/features/screen/capture/driver.dart';capture.parent.mkdir(parents=True);capture.write_text('same stabilized capture and stop pipeline')
   value=apply_private_codec_overlay(flutter,before);self.assertEqual(capture.read_text(),'same stabilized capture and stop pipeline');self.assertIn('driver: QaCodecScreenDriver(',target.read_text());self.assertEqual(value['production_files_modified'],False);self.assertEqual(value['composition_before_sha256'],before)
   with self.assertRaises(ValueError):apply_private_codec_overlay(flutter,before)
 def caps(self,codec='h264',fmtp='profile-level-id=42e01f;packetization-mode=1'):
  return [{'mimeType':'video/'+codec,'clockRate':90000,'sdpFmtpLine':fmtp}]
 def test_h264_requires_explicit_controlled_run_and_every_known_endpoint(self):
  self.assertEqual(controlled_codec('h264',self.caps(),[self.caps()],['h264'],controlled=True)['codec'],'h264')
  for sender,receivers,sfu,controlled in [(None,[self.caps()],['h264'],True),(self.caps(),[None],['h264'],True),(self.caps(),[],['h264'],True),(self.caps(),[self.caps()],None,True),(self.caps(),[self.caps()],['h264'],False)]:
   with self.assertRaises(ValueError):controlled_codec('h264',sender,receivers,sfu,controlled=controlled)
 def test_h264_compatible_profile_uses_common_level_without_sdp_rewrite(self):
  sender=self.caps(fmtp='profile-level-id=42e033;packetization-mode=1;level-asymmetry-allowed=1')
  receiver=self.caps(fmtp='profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1')
  original=[dict(x)for x in sender]
  result=controlled_codec('h264',sender,[receiver],['h264'],controlled=True)
  self.assertEqual(result['expected_profile'],'42e01f');self.assertEqual(result['profile_family'],'42e0');self.assertTrue(result['level_asymmetry_allowed']);self.assertEqual(sender,original)
 def test_h264_unknown_levels_and_invalid_asymmetry_are_not_admitted(self):
  for fmtp in ['profile-level-id=42e000;packetization-mode=1','profile-level-id=42e0ff;packetization-mode=1','profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=2']:
   with self.subTest(fmtp=fmtp),self.assertRaises(ValueError):controlled_codec('h264',self.caps(),[self.caps(fmtp=fmtp)],['h264'],controlled=True)
  value=controlled_codec('h264',self.caps(fmtp='profile-level-id=42e033;packetization-mode=1'),[self.caps()],['h264'],controlled=True)
  self.assertEqual(value['expected_profile'],'42e01f');self.assertFalse(value['level_asymmetry_allowed'])
 def test_h264_profile_packetization_unknown_and_mixed_viewer_are_rejected(self):
  for fmtp in ['', 'profile-level-id=640c1f;packetization-mode=1','profile-level-id=42e01f;packetization-mode=0','profile-level-id=42e01f;packetization-mode=1;packetization-mode=0']:
   with self.subTest(fmtp=fmtp),self.assertRaises(ValueError):controlled_codec('h264',self.caps(),[self.caps(fmtp=fmtp)],['h264'],controlled=True)
  with self.assertRaises(ValueError):controlled_codec('h264',self.caps(),[self.caps(),self.caps('vp8','')],['h264','vp8'],controlled=True)
 def test_codec_selection_is_not_automatic_fallback_or_hardware_proof(self):
  value=controlled_codec('vp8',self.caps('vp8',''),[self.caps('vp8','')],['vp8'],controlled=True)
  self.assertEqual(value['codec'],'vp8');self.assertFalse(value['hardware_proven']);self.assertFalse(value['backup_encoder'])
  with self.assertRaises(ValueError):controlled_codec('h264',self.caps(),[self.caps()],['vp8'],controlled=True)
 def test_order_alternates_three_pairs_for_each_profile_and_source(self):
  rows=alternating_plan();self.assertEqual(len(rows),36)
  for kind in ['window','display']:
   for profile in ['720p60','1080p60','1080p30']:
    cell=[x for x in rows if x['source_kind']==kind and x['profile']==profile];self.assertEqual([x['codec']for x in cell],['vp8','h264','h264','vp8','vp8','h264']);self.assertEqual([x['repeat']for x in cell],[1,1,2,2,3,3])
 def test_unknown_or_changed_control_is_rejected_before_comparison(self):
  a,b=self.row('vp8'),self.row('h264');self.assertEqual(validate_pair(a,b),[])
  for key in ['capture_path','source_pixels','viewer','source_manifest','sdk_manifest','sfu_digest','network','power','source_pattern','bitrate_ceiling_bps','warmup_seconds','window_seconds']:
   with self.subTest(key=key):self.assertIn(key,validate_pair(a,{**b,key:None}));self.assertIn(key,validate_pair(a,{**b,key:'different'}))
 def test_malformed_identical_source_identity_is_not_a_controlled_pair(self):
  for key,value in [('source_manifest','short'),('sdk_manifest','unknown-build'),('sfu_digest','latest'),('source_pixels',[0,1080]),('bitrate_ceiling_bps',0),('warmup_seconds',0),('window_seconds',1)]:
   a,b={**self.row('vp8'),key:value},{**self.row('h264'),key:value}
   with self.subTest(key=key):self.assertIn(key,validate_pair(a,b))
 def test_codec_negotiation_mismatch_invalidates_candidate(self):
  self.assertIn('negotiated_codec',validate_pair(self.row('vp8'),{**self.row('h264'),'negotiated_codec':'vp8'}))
 def test_name_and_codec_do_not_establish_hardware_or_measured_win(self):
  row={**self.row('h264'),'encoder_implementation':'VideoToolbox'}
  self.assertEqual(policy_recommendation([row])['production_default'],'vp8');self.assertFalse(policy_recommendation([row])['hardware_proven']);self.assertEqual(policy_recommendation([row])['status'],'DEFERRED')
 def test_complete_three_to_five_pair_matrix_is_only_ready_for_metric_review(self):
  for repeats in (3,4,5):
   rows=[{**self.row(case['codec']),**case,'status':'PASS','measured':True,'source_pixels':[1920,1080],'capture_path':'stabilized-owned-path'}for case in alternating_plan(repeats)]
   value=policy_recommendation(rows);self.assertEqual(value['status'],'CONTROL_MATRIX_READY_FOR_METRIC_REVIEW');self.assertFalse(value['policy_rollout_enabled']);self.assertFalse(value['hardware_proven'])
 def test_planned_or_unmeasured_matrix_is_never_ready_for_metric_review(self):
  rows=[{**self.row(case['codec']),**case,'source_pixels':[1920,1080],'capture_path':'stabilized-owned-path'}for case in alternating_plan()]
  self.assertEqual(policy_recommendation(rows)['status'],'DEFERRED')
  self.assertEqual(policy_recommendation([{**row,'status':'PASS'}for row in rows])['status'],'DEFERRED')
 def test_identical_ceiling_that_differs_from_profile_is_rejected(self):
  a,b={**self.row('vp8'),'bitrate_ceiling_bps':4000000},{**self.row('h264'),'bitrate_ceiling_bps':4000000}
  self.assertIn('bitrate_ceiling_bps',validate_pair(a,b))
 def test_native_diagnostics_on_off_is_an_explicit_equal_boolean_control(self):
  a,b=self.row('vp8'),self.row('h264')
  self.assertEqual(validate_pair(a,b),[])
  for flag in [False,None,'unknown','true',1]:
   with self.subTest(flag=flag):self.assertIn('capture_diagnostics_enabled',validate_pair(a,{**b,'capture_diagnostics_enabled':flag}))
  self.assertEqual(validate_pair({**a,'capture_diagnostics_enabled':False},{**b,'capture_diagnostics_enabled':False}),[])
 def test_empty_or_incomplete_matrix_cannot_enable_h264(self):
  for rows in [[],[self.row('vp8'),self.row('h264')]]:
   self.assertEqual(policy_recommendation(rows)['production_default'],'vp8');self.assertEqual(policy_recommendation(rows)['status'],'DEFERRED')
if __name__=='__main__':unittest.main()
