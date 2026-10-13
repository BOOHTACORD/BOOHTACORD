"""Offline paired-run recipe and control validation for #331.

Does not publish media, set application codec policy or establish hardware proof.
The physical worker supplies measured rows from the existing #158/#329 harness.
"""
import re

PROFILES = {'720p60': 4_000_000, '1080p60': 8_000_000, '1080p30': 5_000_000}
CONTROLS = ('source_pixels','capture_path','capture_diagnostics_enabled','profile','bitrate_ceiling_bps',
            'source_manifest','sdk_manifest','sfu_digest','source_kind',
            'source_pattern','viewer','network','power','warmup_seconds','window_seconds')

def alternating_plan(repeats=3):
    if not isinstance(repeats,int) or not 3 <= repeats <= 5:
        raise ValueError('Three to five paired repetitions required')
    return [dict(source_kind=kind, profile=profile, codec=codec, repeat=repeat,
                 bitrate_ceiling_bps=ceiling, warmup_seconds=30, window_seconds=180,
                 topology='single-layer', backup_encoder=False,
                 capture_diagnostics_enabled=True, status='NOT_RUN', capture_path='WAIT_FOR_STABILIZED_330_PATH')
            for kind in ('window','display') for profile,ceiling in PROFILES.items()
            for repeat in range(1,repeats+1)
            for codec in (('vp8','h264') if repeat % 2 else ('h264','vp8'))]

def validate_pair(a,b):
    errors=[key for key in CONTROLS
            if a.get(key) in (None,'','unknown','unavailable') or
               b.get(key) in (None,'','unknown','unavailable') or a.get(key)!=b.get(key)]
    for row in (a,b):
        if type(row.get('capture_diagnostics_enabled')) is not bool:
            if 'capture_diagnostics_enabled' not in errors:errors.append('capture_diagnostics_enabled')
        for key in ('source_manifest','sdk_manifest'):
            if not isinstance(row.get(key),str) or not re.fullmatch(r'[0-9a-f]{64}',row[key]):
                if key not in errors:errors.append(key)
        if not isinstance(row.get('sfu_digest'),str) or not re.fullmatch(r'sha256:[0-9a-f]{64}',row['sfu_digest']):
            if 'sfu_digest' not in errors:errors.append('sfu_digest')
        pixels=row.get('source_pixels')
        if not isinstance(pixels,list) or len(pixels)!=2 or any(type(v)is not int or v<=0 for v in pixels):
            if 'source_pixels' not in errors:errors.append('source_pixels')
        for key,minimum in [('warmup_seconds',30),('window_seconds',180),('bitrate_ceiling_bps',1)]:
            if type(row.get(key))is not int or row[key]<minimum:
                if key not in errors:errors.append(key)
    if any(PROFILES.get(row.get('profile'))!=row.get('bitrate_ceiling_bps')for row in (a,b)):
        if 'bitrate_ceiling_bps' not in errors:errors.append('bitrate_ceiling_bps')
    if {a.get('codec'),b.get('codec')} != {'vp8','h264'}:
        errors.append('codec')
    if any(row.get('negotiated_codec') != row.get('codec') for row in (a,b)):
        errors.append('negotiated_codec')
    return errors

def policy_recommendation(rows):
    """Read-only preparation result; production remains conservative pending ADR.

    A complete control matrix goes to metric review, not automatic rollout.
    Codec/implementation strings intentionally never become hardware=true.
    """
    pairs={}
    for row in rows:
        key=(row.get('source_kind'),row.get('profile'),row.get('repeat'))
        pairs.setdefault(key,[]).append(row)
    repetitions={key[2]for key in pairs}
    valid_repetitions=(all(type(r)is int for r in repetitions)and 3<=len(repetitions)<=5 and repetitions==set(range(1,len(repetitions)+1)))
    expected={(k,p,r)for k in ('window','display')for p in PROFILES for r in repetitions}
    complete=(valid_repetitions and set(pairs)==expected and all(len(v)==2 and not validate_pair(*v) and all(row.get('status')=='PASS'and row.get('measured')is True for row in v) for v in pairs.values()))
    return dict(production_default='vp8',hardware_proven=False,
                status='CONTROL_MATRIX_READY_FOR_METRIC_REVIEW' if complete else 'DEFERRED',
                control_matrix_complete=complete,
                policy_rollout_enabled=False,
                reason='Physical stage distributions, bottleneck explanation, compatible viewers and approved cohort ADR are required before policy changes')

def _profiles(capabilities,codec):
    if not isinstance(capabilities,list):raise ValueError('Unknown capability snapshot')
    profiles=set()
    for row in capabilities:
        if not isinstance(row,dict) or str(row.get('mimeType','')).lower()!='video/'+codec or row.get('clockRate')!=90000:continue
        if codec=='vp8':profiles.add(('vp8',));continue
        line=row.get('sdpFmtpLine')
        if not isinstance(line,str):continue
        parameters={};invalid=False
        for part in line.split(';'):
            if not part.strip():continue
            pair=part.split('=',1)
            if len(pair)!=2:invalid=True;break
            key,value=(p.strip().lower()for p in pair)
            if key in parameters:invalid=True;break
            parameters[key]=value
        profile=parameters.get('profile-level-id','')
        asymmetry=parameters.get('level-asymmetry-allowed','0')
        known_levels={10,11,12,13,20,21,22,30,31,32,40,41,42,50,51,52}
        if (not invalid and re.fullmatch(r'42e0[0-9a-f]{2}',profile)
            and int(profile[-2:],16)in known_levels
            and parameters.get('packetization-mode')=='1'and asymmetry in ('0','1')):
            profiles.add(('42e0',int(profile[-2:],16),asymmetry=='1'))
    return profiles

def controlled_codec(requested,sender_caps,receiver_caps,sfu_codecs,*,controlled=False):
    """QA-only requested-codec gate, never automatic production preference.

    H264 admits only known constrained-baseline/packetization-mode 1 profiles.
    RFC6184 profile compatibility is independent of level; the common minimum
    is recorded without writing SDP. Actual codec/FMTP must still be read back.
    No profile SDP rewrite or hardware inference is performed. Unsupported runs
    are deferred instead of silently relabelled as a fallback measurement.
    """
    if controlled is not True or requested not in ('vp8','h264'):raise ValueError('Explicit owned codec experiment required')
    if not isinstance(receiver_caps,list)or not receiver_caps:raise ValueError('Known target receivers required')
    if not isinstance(sfu_codecs,list)or requested not in [str(x).lower().removeprefix('video/')for x in sfu_codecs]:raise ValueError('Unknown or unsupported SFU codec')
    endpoints=[_profiles(sender_caps,requested),*[_profiles(caps,requested)for caps in receiver_caps]]
    if any(not profiles for profiles in endpoints):raise ValueError('No supported common codec/profile')
    selected=[max(profiles,key=lambda p:p[1:])for profiles in endpoints]if requested=='h264'else []
    level=min(p[1]for p in selected)if selected else None
    return dict(codec=requested,expected_profile=f'42e0{level:02x}'if requested=='h264'else None,
                profile_family='42e0'if requested=='h264'else None,
                level_asymmetry_allowed=all(p[2]for p in selected)if selected else None,
                expected_packetization_mode=1 if requested=='h264'else None,
                hardware_proven=False,topology='single-layer',backup_encoder=False,
                status='REQUESTED_ONLY_ACTUAL_NEGOTIATION_REQUIRED')

def apply_private_codec_overlay(flutter,expected_media_sha256):
    """Guarded QA-only common source overlay; baseline source is never touched.

    Apply only after the coordinator admits the existing owned producer snapshot.
    The runtime selector is identical source for both paired codec cases.
    """
    from pathlib import Path
    import hashlib,shutil
    from tools.qa.mini_player.native import source_manifest
    flutter=Path(flutter).resolve();marker=flutter.parent/'.qa98325-owned'
    if flutter.name!='flutter'or not marker.is_file()or marker.read_text()!='owned physical Mac QA\n':raise ValueError('Marked owned Mac private copy required')
    target=flutter/'lib/src/app/composition/media.dart'
    if not target.resolve().is_relative_to(flutter)or not target.is_file():raise ValueError('Private composition unavailable')
    before=hashlib.sha256(target.read_bytes()).hexdigest()
    if not re.fullmatch(r'[0-9a-f]{64}',expected_media_sha256)or before!=expected_media_sha256:raise ValueError('Private source drift')
    source=target.read_text();needle='    voiceReady: () =>\n'
    if source.count(needle)!=1 or source.count('app.screen = ScreenShareController(')!=1 or 'QaCodecScreenDriver'in source:raise ValueError('Unexpected composition shape')
    adapter=Path(__file__).with_name('codec_driver.dart')
    if not adapter.is_file():raise ValueError('QA adapter unavailable')
    capture=flutter/'lib/src/features/screen/capture/driver.dart';capture_before=hashlib.sha256(capture.read_bytes()).hexdigest();lib_before=source_manifest(flutter/'lib')[0]
    destination=flutter/'lib/src/features/screen/rollout/qa_codec_driver.dart';destination.parent.mkdir(parents=True,exist_ok=True)
    if destination.exists():raise ValueError('Existing private codec adapter')
    patched="import '../../features/screen/rollout/qa_codec_driver.dart';\n"+source.replace(needle,'    driver: QaCodecScreenDriver(readRoom: () => app.voice.room),\n'+needle)
    shutil.copy2(adapter,destination);target.write_text(patched)
    assert hashlib.sha256(capture.read_bytes()).hexdigest()==capture_before
    return dict(status='QA_PRIVATE_PATCH_ONLY_NOT_RUNTIME',production_files_modified=False,
                composition_before_sha256=before,composition_after_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                adapter_sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),
                capture_driver_unchanged_sha256=capture_before,
                private_lib_before_sha256=lib_before,private_lib_after_sha256=source_manifest(flutter/'lib')[0],
                runtime_selector='QA_NATIVE_CODEC=vp8|h264; absent delegates unchanged production driver')
