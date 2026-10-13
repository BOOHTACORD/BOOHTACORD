"""Exact-device isolated native roster app, real secure-cookie API."""
import argparse,hashlib,json,os,socket,ssl,subprocess,tempfile
from pathlib import Path
from datetime import datetime,timezone
from tools.qa.mini_player.native import archive_previous,source_manifest,verify_owned_device
from tools.qa.guild_identity.run import current_identity
from .bridge import RosterBridge
import secrets

REQUIRED_NATIVE=('guest_member_acl','initial_503_no_false_zero','populated_rest_sse_two_accounts','realtime_join_leave','refresh_fault_recovery_no_false_zero','logout_clears_roster','login_after_logout_fresh_scope')
def validated_scenario(value,platform):
 if value.get('status')not in ('PASS','PARTIAL')or any(value.get('checks',{}).get(k)!='PASS'for k in REQUIRED_NATIVE):raise RuntimeError('Required native roster scenarios incomplete')
 if platform=='android'and any(value['checks'].get(k)!='PASS'for k in ('background_foreground','listener_rejoin_cleanup')):raise RuntimeError('Android lifecycle incomplete')
 return dict(value,status='PASS'if platform=='android'else'PARTIAL')

def validated_supplement(value):
 if value.get('status')!='PASS' or any(value.get('checks',{}).get(k)!='PASS'for k in ('background_foreground','listener_framebuffer','cleanup')):raise RuntimeError('Supplemental actual phase incomplete')
 if value.get('actual_api') is not True or value.get('actual_sfu') is not True or value.get('mocks') is not False:raise RuntimeError('Supplemental actual transport missing')
 return value

def main():
 p=argparse.ArgumentParser();p.add_argument('--platform',choices=['android','ios'],required=True);p.add_argument('--device',required=True);p.add_argument('--background-only',action='store_true');a=p.parse_args()
 if a.background_only and a.platform!='android':raise ValueError('Android supplemental only')
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa272-20261013'/('android-visual-supplement' if a.background_only else a.platform);out.mkdir(parents=True,exist_ok=True);archive_previous(out)
 os.environ.update(ANDROID_HOME='/opt/homebrew/share/android-commandlinetools',ANDROID_SDK_ROOT='/opt/homebrew/share/android-commandlinetools',JAVA_HOME='/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
 os.environ['PATH']='/opt/homebrew/share/android-commandlinetools/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH','')
 receipt=out/'runtime.json';report={'issue':272,'platform':a.platform,'status':'RUNNING','phase':'preflight','runtime_completed':False,'started_at':datetime.now(timezone.utc).isoformat()}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();private=Path('/private/tmp/boohtacord-qa272-flutter');reversed_ports=[];executable=private/('build/app/outputs/flutter-apk/app-debug.apk' if a.platform=='android' else 'build/ios/iphonesimulator/Runner.app/Runner');build_started=False;bridge=None
 try:
  verify_owned_device(a.platform,a.device);report.update(current_identity(root));inputs=json.loads(Path((out.parent/'active-input-path').read_text()).read_text())
  report['qa_handler_sha256']={n:hashlib.sha256((root/'tools/qa/roster_runtime'/n).read_bytes()).hexdigest() for n in ('native.py','run.py','stack.py','scenario.mjs','bridge.py')}
  holder=json.loads((out.parent/'web/scenario.json').read_text());expected={'scenario_sha256':report['qa_handler_sha256']['scenario.mjs'],'protocol':'owned-string-atomic-control-v1'}
  if holder.get('status')!='PASS'or holder.get('holder_protocol')!=expected:raise RuntimeError('Fresh completed actual publisher holder required')
  if a.platform=='android':
   existing=subprocess.check_output(['adb','-s',a.device,'reverse','--list'],text=True)
   if any('tcp:'+str(port) in existing for port in (5070,5074,5076)):raise RuntimeError('Foreign existing reverse')
   for port in (5070,5074,5076):subprocess.run(['adb','-s',a.device,'reverse','tcp:'+str(port),'tcp:'+str(port)],check=True,stdout=subprocess.DEVNULL);reversed_ports.append(port)
   packages=subprocess.check_output(['adb','-s',a.device,'shell','pm','list','packages','talkback'],text=True);report['talkback_available']=bool(packages.strip())
  with socket.create_connection(('127.0.0.1',5070)) as plain:
   with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as tls:pin=hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
  api_build=out.parent/'fixed-api-build.json';report['api_build_provenance']={'path':str(api_build.relative_to(root)),'sha256':hashlib.sha256(api_build.read_bytes()).hexdigest(),'receipt':json.loads(api_build.read_text())}
  report['phase']='source copy';save();subprocess.run(['rsync','-a','--delete','--exclude','/build','--exclude','/.dart_tool','--exclude','/ios/Pods','--exclude','/ios/.symlinks',str(root/'clients/flutter')+'/',str(private)+'/'],check=True)
  report['flutter_lib_sha256'],report['flutter_lib_file_count']=source_manifest(private/'lib');assert report['flutter_lib_sha256']==source_manifest(root/'clients/flutter/lib')[0]
  report['flutter_package_sources']={str(p.relative_to(private)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [private/'pubspec.yaml',private/'pubspec.lock',*sorted((private/'vendor').rglob('*.dart'))] if p.is_file()}
  report['qa_target_sha256']=hashlib.sha256((private/'integration_test/roster_qa_test.dart').read_bytes()).hexdigest();report['qa_driver_sha256']=hashlib.sha256((private/'test_driver/roster_qa.dart').read_bytes()).hexdigest()
  executable.unlink(missing_ok=True);build_started=True;report['phase']='native drive';save()
  with tempfile.TemporaryDirectory(prefix='qa272-native-',dir='/private/tmp') as temp:
   secret=secrets.token_urlsafe(32);define=Path(temp)/'defines.json';define.write_text(json.dumps({'QA_API_BASE':'https://localhost:5070/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':inputs['password'],'QA_CONTROL':secret,'QA_BACKGROUND_ONLY':a.background_only}));define.chmod(0o600)
   with RosterBridge(out.parent/'web',secret,inputs['owner'],a.platform)as bridge:
    subprocess.run(['flutter','drive','--driver','test_driver/roster_qa.dart','--target','integration_test/roster_qa_test.dart','-d',a.device,'--dart-define-from-file',str(define)],cwd=private,env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(out)),check=True,timeout=900)
   report['control_observations']=bridge.observations
  report['runtime_completed']=True;scenario=json.loads((out/'scenario.json').read_text())
  if a.background_only:scenario=validated_supplement(scenario)
  else:scenario=validated_scenario(scenario,a.platform)
  report.update(scenario)
  report['phase']='complete'
 except Exception as e:
  report.update(status='FAIL',error_type=type(e).__name__,error_phase=report['phase'])
  if (out/'scenario.json').exists():report.update(json.loads((out/'scenario.json').read_text()));report['status']='FAIL'
  raise
 finally:
  errors=[]
  if bridge is not None and any(v['action']=='sfu_stop' for v in bridge.observations):
   try:bridge.control('sfu_start');report['owned_sfu_restored']=True
   except Exception:errors.append('sfu_restore')
  for port in reversed_ports:
   r=subprocess.run(['adb','-s',a.device,'reverse','--remove','tcp:'+str(port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   if r.returncode:errors.append('reverse_cleanup')
  if errors:report['status']='FAIL'
  report.update(owned_reverse_removed=not errors,cleanup_errors=errors,completed_at=datetime.now(timezone.utc).isoformat(),build_mode='debug',device_kind='emulator' if a.platform=='android' else 'simulator',screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},native_executable_sha256=hashlib.sha256(executable.read_bytes()).hexdigest() if build_started and executable.exists() else None);save()
 if report.get('status')!='PASS':raise RuntimeError('Native roster gate partial')

if __name__=='__main__':main()
