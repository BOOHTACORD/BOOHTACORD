import json,unittest
from .codec_diagnostics import parse_codec_diagnostics
class CodecDiagnosticTests(unittest.TestCase):
 def test_bounded_stdout_projection_preserves_observed_reason_never_paths_sdp_identity(self):
  value={'schema_version':1,'event':'admission','phase':'sfu_observed','reason':'observed','room_connected':True,'sfu_snapshot':'empty','sfu_known_codecs':[],'sender_codec_count':8,'viewer_endpoint_count':1,'raw_path':'/private/secret','raw_sdp':'private-sdp','account_id':'private-account','hardware_proven':True}
  result=parse_codec_diagnostics('ordinary private text\nQA_CODEC_DIAGNOSTIC '+json.dumps(value)+'\nQA_CODEC_DIAGNOSTIC malformed')
  self.assertEqual(len(result),1);self.assertEqual(result[0]['sfu_snapshot'],'empty');self.assertFalse(result[0]['hardware_proven']);self.assertNotIn('private',json.dumps(result))
 def test_readback_unknown_numbers_and_codec_are_not_filled_or_exported(self):
  value={'schema_version':1,'event':'readback','status':'deferred','actual_codec':'h264','codec_fmtp':'profile-level-id=42e034;private-token=secret','capture':{'actual_width':1920,'actual_height':1080},'encodings':[{'max_fps':60,'max_bitrate_bps':8000000,'scale_down_by':None,'active':True,'rid':'private'}]}
  row=parse_codec_diagnostics('QA_CODEC_DIAGNOSTIC '+json.dumps(value))[0];self.assertEqual(row['codec_fmtp'],'profile-level-id=42e034');self.assertIsNone(row['encodings'][0]['scale_down_by']);self.assertNotIn('secret',json.dumps(row));self.assertNotIn('rid',row['encodings'][0])

 def test_adapter_actual_profile_and_unavailable_boundary_are_not_silently_dropped(self):
  import json
  events=[{'schema_version':1,'event':'admission','phase':'publish','reason':'readback_unavailable','admitted_profile':'42e01f:1'},{'schema_version':1,'event':'readback','status':'unavailable','admitted_profile':'42e01f:1'}]
  rows=parse_codec_diagnostics('\n'.join('QA_CODEC_DIAGNOSTIC '+json.dumps(e)for e in events));self.assertEqual(rows[0]['phase'],'publish');self.assertEqual(rows[0]['reason'],'readback_unavailable');self.assertEqual(rows[1]['status'],'unavailable');self.assertEqual(rows[1]['admitted_profile'],'42e01f:1')
