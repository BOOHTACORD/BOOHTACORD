"""Dedicated Android/iOS real API message-actions capture; independent verified build tree."""
import argparse
from contextlib import nullcontext
import hashlib
import json
import os
import socket
import ssl
import subprocess
import tempfile
import time
from pathlib import Path
from .stack import Stack
from tools.qa.local_features.native import verify_device
from tools.qa.local_features.process import run_owned


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_manifest(directory):
    return {str(path.relative_to(directory)):digest(path) for path in sorted(directory.rglob('*.dart'))}


def execute(args, output):
    root=Path(__file__).resolve().parents[3]
    flutter=Path('/private/tmp/boohtacord-qa293-flutter')
    sdk='/opt/homebrew/share/android-commandlinetools'
    os.environ.update(ANDROID_HOME=sdk,ANDROID_SDK_ROOT=sdk,JAVA_HOME='/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',DOCKER_CONTEXT='colima-boohtacord-qa')
    os.environ['PATH']=sdk+'/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH','')
    device=args.device or ('emulator-5554' if args.platform=='android' else '82C26E13-0F1F-43F9-AF27-866DC22C2456')
    verify_device(args.platform,device)
    candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    diff_sha=hashlib.sha256(subprocess.check_output(['git','diff','--binary'],cwd=root)).hexdigest()
    manifest=source_manifest(root/'clients/flutter/lib')
    if manifest!=source_manifest(flutter/'lib'): raise ValueError('Independent native app source does not match the reviewed repository')
    metadata={'candidate':candidate,'dirty_diff_sha256':diff_sha,
              'flutter_lib_manifest_sha256':hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest(),
              'app_source_files':{name:manifest[name] for name in ['src/screens/workspace_ui/message_action_menu/component.dart','src/screens/workspace_ui/direct_message_action_menu/component.dart','src/screens/workspace_ui/message_edit_dialog/build/handler.dart']},
              'source_copy_match':True,'build_mode':'debug','device':device,
              'os':subprocess.check_output(['adb','-s',device,'shell','getprop','ro.build.version.release'],text=True).strip() if args.platform=='android' else 'iOS27.0 simulator'}
    if args.platform=='android':
        reverses=subprocess.check_output(['adb','-s',device,'reverse','--list'],text=True)
        if 'tcp:4810' in reverses: raise ValueError('Refusing pre-existing reverse port')
    (output/'runtime.json').write_text(json.dumps(dict(metadata,status='RUNNING',phase='setup'),indent=2)+'\n')
    if args.platform=='android':
        subprocess.run(['adb','-s',device,'reverse','tcp:4810','tcp:4810'],check=True,stdout=subprocess.DEVNULL)
    report={'status':'FAIL','failed_phase':'native build or execution'}
    completed=False
    try:
        with tempfile.TemporaryDirectory(prefix='qa293-native-',dir=root/'.out') as temporary:
            stack=Stack(root,Path(temporary))
            try:
                stack.start()
                with socket.create_connection(('127.0.0.1',4810),timeout=5) as plain:
                    with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as secure:
                        pin=hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
                defines=Path(temporary)/'defines.json'
                defines.write_text(json.dumps({'QA_API_BASE':'https://localhost:4810/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password}))
                defines.chmod(0o600)
                run_owned(['flutter','drive','--driver','test_driver/message_actions_qa.dart','--target','integration_test/message_actions_qa_test.dart','-d',device,'--dart-define-from-file',str(defines)],cwd=flutter,env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(output)),timeout=1200)
                completed=True
            finally:
                stack.close()
    finally:
        if args.platform=='android':
            subprocess.run(['adb','-s',device,'reverse','--remove','tcp:4810'],check=True,stdout=subprocess.DEVNULL)
        if (output/'scenario.json').exists():report=json.loads((output/'scenario.json').read_text())
        if not completed:report['status']='FAIL'
        report.update(metadata,owned_resources_removed=True,screenshots={p.name:digest(p) for p in output.glob('*.png')})
        if completed:
            artifact=flutter/'build/app/outputs/flutter-apk/app-debug.apk' if args.platform=='android' else flutter/'build/ios/iphonesimulator/Runner.app/Runner'
            report['native_artifact_sha256']=digest(artifact)
        (output/'runtime.json').write_text(json.dumps(report,indent=2)+'\n')
    assert report['status'] in ('PASS','PARTIAL') and report.get('checks') and all(value=='PASS' for value in report['checks'].values()), 'Native message-actions scenario did not pass its observed checks'
    assert len(report['screenshots'])>=4,'Native visual evidence missing'
    print('#293 '+args.platform+' observed rows passed; remaining issue gates PARTIAL; owned resources removed',flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--platform',choices=['android','ios'],default='android')
    parser.add_argument('--device')
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    output=root/'.out/qa293-20261012'/args.platform
    output.mkdir(parents=True,exist_ok=True)
    previous=output.parent/'previous-harness-runs'/args.platform/str(time.time_ns())
    if any(output.iterdir()):
        previous.mkdir(parents=True)
        for path in output.iterdir():
            if path.is_file():path.rename(previous/path.name)
    receipt=output/'runtime.json'
    report={'status':'RUNNING','phase':'preflight','platform':args.platform,'owned_resources_removed':False}
    receipt.write_text(json.dumps(report,indent=2)+'\n')
    try:
        execute(args, output)
    except BaseException as error:
        try:
            report=json.loads(receipt.read_text())
        except (OSError,ValueError):
            pass
        report.update(status='FAIL',error_type=type(error).__name__)
        receipt.write_text(json.dumps(report,indent=2)+'\n')
        raise


if __name__=='__main__': main()
