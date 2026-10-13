"""Allowlisted codec observations from the owned sandboxed native process."""
import json,math,re
PHASES={'start','caps_read','sender_caps','sfu_observed','admitted','rejected','publish'}
REASONS={'observed','admitted','phase_not_admitted','caps_missing','invalid_caps','file_access','room_unavailable','room_not_connected','codec_not_compatible','connected_SFU_no_explicit_restriction','sfu_allowlist','readback_unavailable','unknown'}
def number(value,maximum):return value if isinstance(value,(int,float))and not isinstance(value,bool)and math.isfinite(value)and 0<=value<=maximum else None
def parse_codec_diagnostics(text):
 rows=[]
 for line in text.splitlines():
  if not line.startswith('QA_CODEC_DIAGNOSTIC ')or len(line)>8192:continue
  try:value=json.loads(line.removeprefix('QA_CODEC_DIAGNOSTIC '))
  except ValueError:continue
  if not isinstance(value,dict)or value.get('schema_version')!=1 or value.get('event')not in ('admission','readback'):continue
  row={'schema_version':1,'event':value['event'],'hardware_proven':False}
  for key in ('actual_codec','requested_codec'):
   if value.get(key)in ('vp8','h264'):row[key]=value[key]
  profile=value.get('admitted_profile')
  if profile=='vp8'or isinstance(profile,str)and re.fullmatch('42e0[0-9a-f]{2}:1',profile):row['admitted_profile']=profile
  digest=value.get('caps_payload_sha256')
  if isinstance(digest,str)and re.fullmatch('[0-9a-f]{64}',digest):row['caps_payload_sha256']=digest
  if value['event']=='admission':
   row.update(phase=value.get('phase')if value.get('phase')in PHASES else 'rejected',reason=value.get('reason')if value.get('reason')in REASONS else 'unknown',room_connected=value.get('room_connected')if isinstance(value.get('room_connected'),bool)else None,sfu_snapshot=value.get('sfu_snapshot')if value.get('sfu_snapshot')in ('unknown','empty','explicit')else 'unknown',sfu_known_codecs=[c for c in (value.get('sfu_known_codecs')or[])if c in ('vp8','h264')][:2],sender_codec_count=number(value.get('sender_codec_count'),64),viewer_endpoint_count=number(value.get('viewer_endpoint_count'),8),error_class=value.get('error_class')if value.get('error_class')in ('StateError','FileSystemException','FormatException','TimeoutException')else None,os_error_code=value.get('os_error_code')if value.get('os_error_code')in (1,2,13)else None)
  else:
   row['status']=value.get('status')if value.get('status')in ('observed','confirmed','deferred','mismatch','timeout','unavailable')else 'unknown'
   if value.get('method')=='fresh_pc_getSenders_and_actual_outbound_codecId':row['method']=value['method']
   fmtp=value.get('codec_fmtp');parts=[p.strip()for p in fmtp.split(';')if re.fullmatch(r'(profile-level-id|packetization-mode|level-asymmetry-allowed)=[0-9a-f]{1,6}',p.strip(),re.I)]if isinstance(fmtp,str)and len(fmtp)<=256 else []
   row['codec_fmtp']=';'.join(parts[:3])or None
   capture=value.get('capture');row['capture']={k:number(capture.get(k),16384)for k in ('actual_width','actual_height','configured_width','configured_height','configured_max_fps')}if isinstance(capture,dict)else None
   row['encodings']=[{k:number(e.get(k),maxval)for k,maxval in [('max_fps',240),('max_bitrate_bps',100000000),('scale_down_by',64)]}|{'active':e.get('active')if isinstance(e.get('active'),bool)else None}for e in value.get('encodings',[])[:2]if isinstance(e,dict)]
  rows.append(row)
  if len(rows)>=128:break
 return rows
