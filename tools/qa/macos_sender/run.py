"""Build the isolated physical Mac Debug acceptance app and own real stack."""
import argparse,base64,hashlib,json,os,shutil,socket,ssl,subprocess,sys,tempfile,time
from pathlib import Path
from .stack import Stack
from .policy import PORTS,namespace,output_name
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'.out'/output_name(os.environ.get('BOOHTACORD_QA_RUN_NAME','qa98325-20261013'))

def private_json(path,value):
 path.write_text(json.dumps(value));path.chmod(0o600)

def request_fixture(stack):
 import http.client
 from http.cookies import SimpleCookie
 cookie=''
 def request(path,method='GET',body=None):
  connection=http.client.HTTPSConnection('localhost',5060,context=ssl._create_unverified_context(),timeout=15)
  try:
   connection.request(method,'/api/v1'+path,None if body is None else json.dumps(body),{'Origin':'https://localhost:5060','Cookie':cookie,'Content-Type':'application/json'})
   response=connection.getresponse();raw=response.read();return response.status,json.loads(raw) if raw else None,dict(response.getheaders())
  finally:connection.close()
 status,_,headers=request('/auth/login','POST',{'login':'qa_admin','password':stack.password})
 if status!=204:raise RuntimeError('Fixture login rejected')
 jar=SimpleCookie(headers['Set-Cookie']);cookie='vp_session='+jar['vp_session'].value
 status,category,_=request('/admin/categories','POST',{'name':'QaStartupSender'})
 if status!=201:raise RuntimeError('Fixture category rejected')
 status,_,_=request('/admin/categories/'+category['id']+'/channels','POST',{'name':'QaVoice','kind':'VOICE'})
 if status!=201:raise RuntimeError('Fixture voice channel rejected')
 status,_,_=request('/auth/register','POST',{'login':'qa_sender_peer','password':stack.password})
 if status!=201:raise RuntimeError('Fixture peer rejected')

def qa_copy_plan():
 plan=(('native_app.dart','integration_test/qa98325_native_app.dart'),('stage_scene.dart','integration_test/qa98325_stage_scene.dart'),('stage_scene_test.dart','test/qa98325_stage_scene_test.dart'),('descriptor_observer.dart','integration_test/qa98325_descriptor_observer.dart'),('descriptor_observer_test.dart','test/qa98325_descriptor_observer_test.dart'),('source_policy.dart','integration_test/qa98325_source_policy.dart'),('source_policy_test.dart','test/qa98325_source_policy_test.dart'),('lifecycle_acceptance.dart','integration_test/qa98325_lifecycle_acceptance.dart'),('lifecycle_acceptance_test.dart','test/qa98325_lifecycle_acceptance_test.dart'),('receiver_observer.dart','integration_test/qa98325_receiver_observer.dart'),('receiver_observer_test.dart','test/qa98325_receiver_observer_test.dart'),('capture_observer.dart','integration_test/qa98325_capture_observer.dart'),('capture_observer_test.dart','test/qa98325_capture_observer_test.dart'),('namespace_storage.dart','integration_test/qa98325_namespace_storage.dart'),('http_observer.dart','integration_test/qa98325_http_observer.dart'),('namespace_storage_test.dart','test/qa98325_namespace_storage_test.dart'),('http_observer_test.dart','test/qa98325_http_observer_test.dart'),('real_http_deadline_test.dart','test/qa98325_real_http_deadline_test.dart'))
 if any(len(row)!=2 for row in plan) or len({row[1] for row in plan})!=len(plan):raise ValueError('Malformed QA source copy plan')
 for original,destination in plan:
  if not Path(__file__).with_name(original).is_file() or not destination.startswith(('integration_test/qa98325_','test/qa98325_')) or '..' in destination:raise ValueError('Unbounded QA source copy destination')
 return plan

def adapt_legacy_mode_entry(flutter):
 if (flutter/'lib/src/features/screen/profile/content_mode.dart').is_file():return
 entry=flutter/'integration_test/qa98325_native_app.dart';source=entry.read_text()
 imported="import 'package:boohtacord_desktop/src/features/screen/profile/content_mode.dart';\n"
 named="contentMode:stageContentMode=='text'?ScreenShareContentMode.text:ScreenShareContentMode.motion,"
 if source.count(imported)!=1 or source.count(named)not in (2,3):raise ValueError('Unexpected legacy QA entry shape')
 source=source.replace(imported,'').replace(named,'')
 marker=" final stageContentMode=qaContentMode(Platform.environment['QA_NATIVE_MODE']);"
 source=source.replace(marker,marker+"\n if(stageContentMode!='motion')throw StateError('Legacy baseline has no independent mode');")
 entry.write_text(source)

def main():
 qa_copy_plan()
 parser=argparse.ArgumentParser();parser.add_argument('--prepare-only',action='store_true');parser.add_argument('--source-copy');parser.add_argument('--trusted-chain',action='store_true');parser.add_argument('--backend-copy');args=parser.parse_args()
 source=ROOT/'clients/flutter'
 if args.source_copy:
  source=Path(args.source_copy).resolve()
  if source.parent.parent!=OUT.resolve() or not (source.parent/'.qa98325-baseline-source').is_file():raise ValueError('Marked owned baseline source required')
 expected_source_manifest=manifest(source/'lib')
 backend=None
 if args.backend_copy:
  backend=Path(args.backend_copy).resolve()
  if backend.parent.parent.parent!=OUT.resolve() or not (backend.parent/'.qa98325-baseline-backend').is_file():raise ValueError('Marked own baseline API source required')
 if sys.platform!='darwin':raise RuntimeError('Physical macOS required')
 OUT.mkdir(parents=True,exist_ok=True)
 old=OUT/'runtime.json'
 if old.exists():
  archive=OUT/'previous'/str(time.time_ns());archive.mkdir(parents=True);old.rename(archive/'runtime.json')
 old.write_text(json.dumps({'status':'RUNNING','phase':'setup','owned_resources_removed':False})+'\n')
 os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa';os.environ['PATH']='/opt/homebrew/bin:'+os.environ['PATH']
 with tempfile.TemporaryDirectory(prefix='owned-',dir=OUT) as temporary:
  work=Path(temporary);work.chmod(0o700);(work/'.qa98325-owned').write_text('owned physical Mac QA\n');stack=Stack(ROOT,work/'stack',backend_copy=backend);(work/'stack').mkdir()
  report={'status':'RUNNING','base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'physical_macOS':True,'owned_resources_removed':False}
  try:
   stack.start();request_fixture(stack)
   with socket.create_connection(('127.0.0.1',5060)) as socket_plain:
    with ssl._create_unverified_context().wrap_socket(socket_plain,server_hostname='localhost') as secure:pin=hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
   private_json(work/'browser-private.json',{'password':stack.password})
   flutter=work/'flutter'
   subprocess.run(['rsync','-a','--exclude','/build/','--exclude','/.dart_tool/','--exclude','/macos/Pods/','--exclude','/macos/Flutter/ephemeral/','--exclude','.git','--exclude','.env',str(source)+'/',str(flutter)+'/'],check=True)
   bundle=flutter/'macos/Runner/Configs/AppInfo.xcconfig';bundle.write_text(bundle.read_text().replace('ru.boohtacord.boohtacordDesktop','ru.boohtacord.localqa'))
   for original,new in qa_copy_plan():shutil.copy2(Path(__file__).with_name(original),flutter/new)
   adapt_legacy_mode_entry(flutter)
   suffix=stack.owner.removeprefix('qa98325-');defines={'QA_API_BASE':'https://localhost:5060/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password,'QA_STORAGE_NAMESPACE':namespace(suffix)}
   if args.trusted_chain:
    ca=work/'owned-ca.crt';subprocess.run(['docker','cp',stack.owner+'-proxy:/data/caddy/pki/authorities/local/root.crt',str(ca)],check=True,stdout=subprocess.DEVNULL)
    defines['QA_TRUSTED_CA_B64']=base64.b64encode(ca.read_bytes()).decode();report['native_TLS_trust']='SecurityContext exact own CA; normal certificate/hostname validation, no badCertificateCallback'
   private_json(work/'debug-private-defines.json',defines)
   private_json(work/'configuration.json',{'root':str(ROOT),'work':str(work),'owner':stack.owner,'flutter':str(flutter)})
   report.update(phase='prepared',flutter_lib_manifest_sha256=expected_source_manifest,qa_source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(__file__).parent.glob('*.dart')},web_artifact_manifest_sha256=stack.web_artifact_sha256,private_work=str(work))
   old.write_text(json.dumps(report,indent=2)+'\n');print('PREPARED: owned5060 realAPI/SFU and private native source; request SDK lease before compile',flush=True)
   input('Enter with SDK lease to compile; EOF keeps acceptance incomplete.\n')
   if args.prepare_only:return
   with (work/'build-private.log').open('w') as log:
    subprocess.run(['flutter','pub','get','--offline'],cwd=flutter,stdout=log,stderr=subprocess.STDOUT,check=True)
    subprocess.run(['flutter','test','--no-pub','test/qa98325_stage_scene_test.dart','test/qa98325_capture_observer_test.dart','test/qa98325_descriptor_observer_test.dart','test/qa98325_source_policy_test.dart','test/qa98325_namespace_storage_test.dart','test/qa98325_http_observer_test.dart','test/qa98325_real_http_deadline_test.dart','test/api_session_restore_test.dart','test/screen_share_report_isolation_test.dart','test/screen_share_report_cadence_test.dart','test/screen_share_report_payload_test.dart','test/screen_share_stats_poller_test.dart','test/screen_metrics_report_api_test.dart','test/screen_share_report_error_class_test.dart','test/qa98325_lifecycle_acceptance_test.dart','test/qa98325_receiver_observer_test.dart','--reporter','expanded'],cwd=flutter,stdout=log,stderr=subprocess.STDOUT,check=True)
    subprocess.run(['flutter','build','macos','--debug','--no-pub','-t','integration_test/qa98325_native_app.dart','--dart-define-from-file',str(work/'debug-private-defines.json')],cwd=flutter,stdout=log,stderr=subprocess.STDOUT,check=True)
   if expected_source_manifest!=manifest(flutter/'lib'):raise RuntimeError('Native source drifted during compilation')
   report['QA_sources_measured_after_build']={destination:hashlib.sha256((flutter/destination).read_bytes()).hexdigest() for _,destination in qa_copy_plan()}
   artifact=flutter/'build/macos/Build/Products/Debug/BOOHTACORD.app';report.update(phase='BUILT',artifact_path=str(artifact),app_bundle_manifest_sha256=bundle_manifest(artifact),artifact_sha256=hashlib.sha256((artifact/'Contents/MacOS/BOOHTACORD').read_bytes()).hexdigest())
   old.write_text(json.dumps(report,indent=2)+'\n');print('BUILT: physical Mac Debug QA; SDK lease can be released now',flush=True)
   print('Use tools.qa.macos_sender.observe with the owned work path; retain stack until physical runs and cleanup complete',flush=True)
   input('Enter after owned app/Keychain cleanup to dispose stack/private build.\n')
   report['status']='PARTIAL';report['phase']='disposed'
  except BaseException as error:report.update(status='FAIL',error_type=type(error).__name__);raise
  finally:
   try:stack.close();report['owned_resources_removed']=not stack.resources
   except Exception as error:report.update(status='FAIL',cleanup_error_type=type(error).__name__)
   report.pop('private_work',None);report.pop('artifact_path',None);old.write_text(json.dumps(report,indent=2)+'\n')

def bundle_manifest(directory):
 return hashlib.sha256(json.dumps({str(p.relative_to(directory)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(directory.rglob('*')) if p.is_file()},sort_keys=True).encode()).hexdigest()

def manifest(directory):
 return hashlib.sha256(json.dumps({str(p.relative_to(directory)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(directory.rglob('*.dart'))},sort_keys=True).encode()).hexdigest()
if __name__=='__main__':main()
