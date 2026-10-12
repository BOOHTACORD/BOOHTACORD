"""Owned actual Android/iOS DM acceptance, exact source and fresh artifacts."""
import argparse
from contextlib import nullcontext
import hashlib,json,os,socket,ssl,subprocess,tempfile
from datetime import datetime,timezone
from pathlib import Path
from .integrity import archive_previous,validate_device,validate_report
from .os_control import AndroidLifecycleBridge
from .stack import Stack
from tools.qa.local_features.process import run_owned
REQUIRED=['list_empty_composer_visible','UI_send_real_history','per_conversation_drafts','search_result_original_context_draft','per_origin_query_scope_back_resize','OS_clipboard_controlled_paste','long_multiline_composer_layout','real_server_third_admin_DM_ACL']
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def manifest(directory):return {str(p.relative_to(directory)):digest(p) for p in sorted(Path(directory).rglob('*')) if p.is_file()}
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--platform',choices=['android','ios'],required=True);parser.add_argument('--device');args=parser.parse_args()
    root=Path(__file__).resolve().parents[3];private=Path('/private/tmp/boohtacord-qa294-flutter');sdk='/opt/homebrew/share/android-commandlinetools'
    os.environ.update(ANDROID_HOME=sdk,ANDROID_SDK_ROOT=sdk,JAVA_HOME='/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',DOCKER_CONTEXT='colima-boohtacord-qa');os.environ['PATH']=sdk+'/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH','')
    device=args.device or ('emulator-5556' if args.platform=='android' else '82C26E13-0F1F-43F9-AF27-866DC22C2456')
    output=root/'.out/qa294-20261012'/args.platform;output.mkdir(parents=True,exist_ok=True);archive_previous(output)
    report={'issue':294,'status':'RUNNING','platform':args.platform,'phase':'preflight','started_at':datetime.now(timezone.utc).isoformat(),'runtime_completed':False,'owned_resources_removed':False,'owned_reverses_removed':False}
    def save(): (output/'runtime.json').write_text(json.dumps(report,indent=2)+'\n')
    save();stack=None;created=[];artifact=None
    try:
        validate_device(args.platform,device)
        lib=manifest(root/'clients/flutter/lib');report.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),dirty_diff_sha256=hashlib.sha256(subprocess.check_output(['git','diff','--binary'],cwd=root)).hexdigest(),flutter_lib_manifest_sha256=hashlib.sha256(json.dumps(lib,sort_keys=True).encode()).hexdigest(),device=device,build_mode='debug')
        paths=['clients/flutter/integration_test/dm_composer_qa_test.dart','clients/flutter/test_driver/dm_composer_qa.dart','tools/qa/dm_composer/run_native.py','tools/qa/dm_composer/stack.py','tools/qa/dm_composer/os_control.py','tools/qa/dm_composer/integrity.py'];report['qa_source_files']={p:digest(root/p) for p in paths};save()
        if manifest(private/'lib')!=lib:raise ValueError('Private Flutter lib must match selected source')
        for p in paths[:2]:
            if digest(private/Path(p).relative_to('clients/flutter'))!=report['qa_source_files'][p]:raise ValueError('Private QA target/driver differs from source')
        bridge=AndroidLifecycleBridge(device) if args.platform=='android' else nullcontext()
        artifact=private/('build/app/outputs/flutter-apk/app-debug.apk' if args.platform=='android' else 'build/ios/iphonesimulator/Runner.app/Runner');artifact.unlink(missing_ok=True)
        with tempfile.TemporaryDirectory(prefix='qa294-native-',dir=root/'.out') as temporary:
            stack=Stack(root,Path(temporary));report['phase']='owned stack';save();stack.start();report.update(backend_source_manifest_sha256=stack.backend_source_manifest_sha256,backend_image_id=stack.backend_image_id);save()
            with socket.create_connection(('127.0.0.1',4940),timeout=5) as plain:
                with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as tls:pin=hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
            if args.platform=='android':
                ports=(4940,4944,4993);old=subprocess.check_output(['adb','-s',device,'reverse','--list'],text=True)
                if any('tcp:'+str(p) in old for p in ports):raise ValueError('Refusing preexisting reverse')
                for p in ports:subprocess.run(['adb','-s',device,'reverse','tcp:'+str(p),'tcp:'+str(p)],check=True,stdout=subprocess.DEVNULL);created.append(p)
            defines=Path(temporary)/'defines.json';defines.write_text(json.dumps({'QA_API_BASE':'https://localhost:4940/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password,'QA_CONTROL_KEY':bridge.key if args.platform=='android' else ''}));defines.chmod(0o600)
            report['phase']='native drive';save()
            with bridge:run_owned(['flutter','drive','--driver','test_driver/dm_composer_qa.dart','--target','integration_test/dm_composer_qa_test.dart','-d',device,'--dart-define-from-file',str(defines)],cwd=private,env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(output)),timeout=1500)
            scenario=validate_report(json.loads((output/'scenario.json').read_text()),REQUIRED+(['emulator_OS_background_foreground_draft'] if args.platform=='android' else []))
            if len(list(output.glob('*.png')))<8:raise ValueError('Required native visual captures missing')
            report.update(scenario,runtime_completed=True,phase='complete')
    except BaseException as error:
        scenario=output/'scenario.json'
        if scenario.exists():report.update(json.loads(scenario.read_text()))
        report.update(status='FAIL',error_type=type(error).__name__,runner_failed_phase=report.get('phase'));raise
    finally:
        errors=[]
        if stack is not None:
            try:stack.close();report['owned_resources_removed']=True
            except Exception as error:errors.append(type(error).__name__)
        for p in reversed(created):
            try:subprocess.run(['adb','-s',device,'reverse','--remove','tcp:'+str(p)],check=True,stdout=subprocess.DEVNULL)
            except Exception as error:errors.append(type(error).__name__)
        report['owned_reverses_removed']=not errors
        if errors:report.update(status='FAIL',cleanup_errors=errors)
        report.update(completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:digest(p) for p in output.glob('*.png')},native_artifact_sha256=digest(artifact) if artifact is not None and artifact.exists() else None);save()
        if errors:raise RuntimeError('Own QA cleanup incomplete')
if __name__=='__main__':main()
