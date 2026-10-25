"""Frozen candidate build on the existing owned stack and Mac acceptance entry."""
import argparse,base64,hashlib,json,os,re,shutil,subprocess
from pathlib import Path
from .run import ROOT,OUT,qa_copy_plan,manifest,bundle_manifest
from .observe import owned_work
from .codec_experiment import apply_private_codec_overlay

def verify_files(root,files):
 root=Path(root).resolve()
 for relative,digest in files.items():
  path=root/relative
  if Path(relative).is_absolute() or '..' in Path(relative).parts or not path.resolve().is_relative_to(root) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise ValueError('Frozen source mismatch')

def completed_build_receipt(report,bundle_sha256,launcher_sha256,qa_sources):
 if report.get('status')!='RUNNING' or not all(re.fullmatch('[0-9a-f]{64}',v or '')for v in (bundle_sha256,launcher_sha256)):raise ValueError('Fresh running build and complete artifact identity required')
 result={k:v for k,v in report.items()if k not in ('no_build_completion_observed','error_type')}
 result.update(status='BUILT',phase='BUILT',app_bundle_manifest_sha256=bundle_sha256,artifact_sha256=launcher_sha256,QA_sources_measured_after_build=qa_sources)
 return result

def codec_caps_document(receiver):
 if not isinstance(receiver,list)or not receiver:raise ValueError('Actual receiver capabilities required')
 normalized=[{**row,'sdpFmtpLine':';'.join(row.get('fmtp',[]))}for row in receiver]
 return {'schema_version':1,'measured':True,'receiver_capabilities':[normalized]}

def codec_environment(work):
 work=Path(work).resolve();marker=work/'.qa98325-owned';caps=work/'codec-receivers-private.json'
 if marker.is_symlink()or marker.read_bytes()!=b'owned physical Mac QA\n'or caps.is_symlink()or not caps.is_file()or caps.stat().st_mode&0o777!=0o600:raise ValueError('Canonical marked private measured codec input required')
 raw=caps.read_bytes()
 if len(raw)>65536:raise ValueError('Bounded codec capabilities required')
 document=json.loads(raw)
 if document.get('schema_version')!=1 or document.get('measured')is not True or not isinstance(document.get('receiver_capabilities'),list)or len(document['receiver_capabilities'])!=1:raise ValueError('Actual single receiver capabilities required')
 rows=[]
 for row in document['receiver_capabilities'][0]:
  if row.get('mimeType','').lower()not in ('video/vp8','video/h264'):continue
  if row.get('clockRate')!=90000:raise ValueError('Video clock required')
  fmtp=row.get('sdpFmtpLine','')
  if not isinstance(fmtp,str)or any(not re.fullmatch(r'(profile-level-id|packetization-mode|level-asymmetry-allowed)=[0-9a-f]{1,6}',part.strip(),re.I)for part in fmtp.split(';')if part.strip()):raise ValueError('Allowlisted codec parameters required')
  rows.append({'mimeType':row['mimeType'],'clockRate':90000,'sdpFmtpLine':fmtp})
 if not rows or len(rows)>32:raise ValueError('Bounded known actual codecs required')
 payload=json.dumps({'schema_version':1,'measured':True,'receiver_capabilities':[rows],'ownership_proof':{'kind':'marked_physical_mac_qa','marker_sha256':hashlib.sha256(marker.read_bytes()).hexdigest(),'source_caps_sha256':hashlib.sha256(raw).hexdigest()}},sort_keys=True,separators=(',',':')).encode()
 if len(payload)>65536:raise ValueError('Bounded codec transport required')
 return {'QA_NATIVE_CODEC_CAPS_B64':base64.b64encode(payload).decode(),'QA_NATIVE_CODEC_CAPS_SHA256':hashlib.sha256(payload).hexdigest()}

def main():
 p=argparse.ArgumentParser();p.add_argument('--template',required=True);args=p.parse_args()
 template=owned_work(args.template);work=OUT/'owned-candidate'
 if work.exists():raise ValueError('Candidate destination already exists')
 main=json.loads((ROOT/'.out/qa-batch5-20261013/main-candidate-final-freeze.json').read_text())
 vendor=json.loads((ROOT/'.out/qa-batch5-20261013/capture-candidate-final-freeze-v4-SOURCE-ONLY.json').read_text())
 verify_files(ROOT/'clients/flutter/lib',main['files']);verify_files(ROOT,vendor['files'])
 work.mkdir(mode=0o700);(work/'.qa98325-owned').write_text('owned physical Mac QA\n')
 source=ROOT/'clients/flutter';flutter=work/'flutter'
 report={'status':'RUNNING','phase':'preparing','main_lib_frozen_sha256':main['sha256'],'vendor_frozen_sha256':vendor['sha256'],'vendor_frozen_scope':'Canonical SOURCE ONLY v4','native_TLS':'exact owned CA SecurityContext, normal hostname validation','build_kind':'unsigned physical macOS Debug QA, not release acceptance'}
 proof=OUT/'candidate-build-proof.json';proof.write_text(json.dumps(report,indent=2)+'\n')
 try:
  subprocess.run(['rsync','-a','--exclude','/packages/','--exclude','/build/','--exclude','/.dart_tool/','--exclude','/macos/Pods/','--exclude','/macos/Flutter/ephemeral/',str(source)+'/',str(flutter)+'/'],check=True)
  for name in ('boohtacord_voice_foreground','flutter_background'):
   subprocess.run(['rsync','-a','--exclude','build/','--exclude','.dart_tool/',str(source/'packages'/name)+'/',str(flutter/'packages'/name)+'/'],check=True)
  for relative in vendor['files']:
   destination=flutter/Path(relative).relative_to('clients/flutter');destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/relative,destination)
  verify_files(flutter/'lib',main['files'])
  bundle=flutter/'macos/Runner/Configs/AppInfo.xcconfig';bundle.write_text(bundle.read_text().replace('ru.boohtacord.boohtacordDesktop','ru.boohtacord.localqa'))
  for original,destination in qa_copy_plan():shutil.copy2(Path(__file__).with_name(original),flutter/destination)
  for name in ('browser-private.json','debug-private-defines.json','owned-ca.crt'):
   shutil.copy2(template/name,work/name);(work/name).chmod(0o600)
  configuration=json.loads((template/'configuration.json').read_text());configuration.update(work=str(work),flutter=str(flutter));(work/'configuration.json').write_text(json.dumps(configuration));(work/'configuration.json').chmod(0o600)
  receiver=json.loads((OUT/'receiver-1.json').read_text())['capabilities']['receiver']
  (work/'codec-receivers-private.json').write_text(json.dumps(codec_caps_document(receiver)));(work/'codec-receivers-private.json').chmod(0o600)
  report['codec_private_overlay']=apply_private_codec_overlay(flutter,main['files']['src/app/composition/media.dart'])
  expected=manifest(flutter/'lib');report['compiled_lib_with_QA_overlay_sha256']=expected
  report['phase']='BUILDING';proof.write_text(json.dumps(report,indent=2)+'\n');print('Candidate prepared from verified main/vendor freezes; compiling physical macOS Debug',flush=True)
  with (work/'candidate-build-private.log').open('w') as log:
   def call(command):subprocess.run(command,cwd=flutter,stdout=log,stderr=subprocess.STDOUT,check=True)
   call(['flutter','pub','get','--offline'])
   call(['flutter','analyze','--no-pub','--no-fatal-infos','integration_test/qa98325_native_app.dart'])
   call(['flutter','test','--no-pub','test/qa98325_stage_scene_test.dart','test/qa98325_capture_observer_test.dart','test/qa98325_descriptor_observer_test.dart','test/qa98325_source_policy_test.dart','test/qa98325_http_observer_test.dart','test/qa98325_lifecycle_acceptance_test.dart','test/qa98325_receiver_observer_test.dart','test/qa98325_namespace_storage_test.dart','test/qa98325_real_http_deadline_test.dart','--reporter','expanded'])
   call(['flutter','build','macos','--debug','--no-pub','-t','integration_test/qa98325_native_app.dart','--dart-define-from-file',str(work/'debug-private-defines.json'),'--dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=screen_capture_kit'])
  if expected!=manifest(flutter/'lib'):raise ValueError('Private candidate source drift during compilation')
  artifact=flutter/'build/macos/Build/Products/Debug/BOOHTACORD.app'
  report=completed_build_receipt(report,bundle_manifest(artifact),hashlib.sha256((artifact/'Contents/MacOS/BOOHTACORD').read_bytes()).hexdigest(),{new:hashlib.sha256((flutter/new).read_bytes()).hexdigest()for _,new in qa_copy_plan()})
  print('Candidate BUILT; release SDK lease now; existing stack remains owned',flush=True)
 except BaseException as error:report.update(status='FAIL',error_type=type(error).__name__);raise
 finally:proof.write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
