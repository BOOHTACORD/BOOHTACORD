"""Exact-device isolated native accessibility app, real secure-cookie API."""
import argparse,hashlib,json,os,socket,ssl,subprocess,tempfile
from pathlib import Path
from datetime import datetime,timezone
from tools.qa.mini_player.native import archive_previous,source_manifest,verify_owned_device
from tools.qa.guild_identity.run import current_identity

REQUIRED_NATIVE = ('guild_native_navigation_named_keyboard','chat_native_semantics_2x','dm_native_route_semantics_2x','seven_admin_tabs_named_selected_2x','settings_native_tabs_2x','native_dialog_keyboard_cancel_escape_2x','native_voice_prejoin_names_2x')

def validated_scenario(scenario, platform):
 if scenario.get('status') not in ('PASS','PARTIAL') or any(scenario.get('checks',{}).get(k)!='PASS' for k in REQUIRED_NATIVE):
  raise RuntimeError('Required native accessibility checks incomplete')
 stream=scenario['checks'].get('native_stream_setup_names_2x')
 if platform=='android' and stream!='PASS':raise RuntimeError('Android stream setup incomplete')
 if platform=='ios' and stream=='NOT_RUN':return dict(scenario,status='PARTIAL')
 if stream!='PASS':raise RuntimeError('Native stream setup incomplete')
 return dict(scenario,status='PASS')

def main():
 p=argparse.ArgumentParser();p.add_argument('--platform',choices=['android','ios'],required=True);p.add_argument('--device',required=True);a=p.parse_args()
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa301-20261012'/a.platform;out.mkdir(parents=True,exist_ok=True);archive_previous(out)
 os.environ.update(ANDROID_HOME='/opt/homebrew/share/android-commandlinetools',ANDROID_SDK_ROOT='/opt/homebrew/share/android-commandlinetools',JAVA_HOME='/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
 os.environ['PATH']='/opt/homebrew/share/android-commandlinetools/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH','')
 receipt=out/'runtime.json';report={'issue':301,'platform':a.platform,'status':'RUNNING','phase':'preflight','runtime_completed':False,'started_at':datetime.now(timezone.utc).isoformat()}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save();private=Path('/private/tmp/boohtacord-qa301-flutter');reversed_ports=[];executable=private/('build/app/outputs/flutter-apk/app-debug.apk' if a.platform=='android' else 'build/ios/iphonesimulator/Runner.app/Runner');build_started=False
 try:
  verify_owned_device(a.platform,a.device);report.update(current_identity(root));inputs=json.loads(Path((out.parent/'active-input-path').read_text()).read_text())
  report['qa_handler_sha256']={n:hashlib.sha256((root/'tools/qa/accessibility_runtime'/n).read_bytes()).hexdigest() for n in ('native.py','run.py','stack.py','scenario.mjs')}
  if a.platform=='android':
   existing=subprocess.check_output(['adb','-s',a.device,'reverse','--list'],text=True)
   if any('tcp:'+str(port) in existing for port in (4930,4984)):raise RuntimeError('Foreign existing reverse')
   for port in (4930,4984):subprocess.run(['adb','-s',a.device,'reverse','tcp:'+str(port),'tcp:'+str(port)],check=True,stdout=subprocess.DEVNULL);reversed_ports.append(port)
   packages=subprocess.check_output(['adb','-s',a.device,'shell','pm','list','packages','talkback'],text=True);report['talkback_available']=bool(packages.strip())
  with socket.create_connection(('127.0.0.1',4930)) as plain:
   with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as tls:pin=hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
  report['phase']='source copy';save();subprocess.run(['rsync','-a','--delete','--exclude','/build','--exclude','/.dart_tool','--exclude','/ios/Pods','--exclude','/ios/.symlinks',str(root/'clients/flutter')+'/',str(private)+'/'],check=True)
  report['flutter_lib_sha256'],report['flutter_lib_file_count']=source_manifest(private/'lib');assert report['flutter_lib_sha256']==source_manifest(root/'clients/flutter/lib')[0]
  report['qa_target_sha256']=hashlib.sha256((private/'integration_test/accessibility_qa_test.dart').read_bytes()).hexdigest();report['qa_driver_sha256']=hashlib.sha256((private/'test_driver/accessibility_qa.dart').read_bytes()).hexdigest()
  executable.unlink(missing_ok=True);build_started=True;report['phase']='native drive';save()
  with tempfile.TemporaryDirectory(prefix='qa301-native-',dir='/private/tmp') as temp:
   define=Path(temp)/'defines.json';define.write_text(json.dumps({'QA_API_BASE':'https://localhost:4930/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':inputs['password']}));define.chmod(0o600)
   subprocess.run(['flutter','drive','--driver','test_driver/accessibility_qa.dart','--target','integration_test/accessibility_qa_test.dart','-d',a.device,'--dart-define-from-file',str(define)],cwd=private,env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(out)),check=True,timeout=900)
  report['runtime_completed']=True;scenario=validated_scenario(json.loads((out/'scenario.json').read_text()),a.platform);report.update(scenario)
  report['phase']='complete'
 except Exception as e:
  report.update(status='FAIL',error_type=type(e).__name__,error_phase=report['phase'])
  if (out/'scenario.json').exists():report.update(json.loads((out/'scenario.json').read_text()));report['status']='FAIL'
  raise
 finally:
  errors=[]
  for port in reversed_ports:
   r=subprocess.run(['adb','-s',a.device,'reverse','--remove','tcp:'+str(port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   if r.returncode:errors.append('reverse_cleanup')
  if errors:report['status']='FAIL'
  report.update(owned_reverse_removed=not errors,cleanup_errors=errors,completed_at=datetime.now(timezone.utc).isoformat(),build_mode='debug',device_kind='emulator' if a.platform=='android' else 'simulator',screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},native_executable_sha256=hashlib.sha256(executable.read_bytes()).hexdigest() if build_started and executable.exists() else None);save()
 if report.get('status')!='PASS':raise RuntimeError('Native accessibility gate partial')

if __name__=='__main__':main()
