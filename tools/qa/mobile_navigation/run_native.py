"""Dedicated mobile navigation real API capture; independent verified build tree."""
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


def install_reverses(device, ports, created):
    for port in ports:
        subprocess.run(['adb', '-s', device, 'reverse', f'tcp:{port}', f'tcp:{port}'], check=True, stdout=subprocess.DEVNULL)
        created.append(port)


def remove_reverses(device, created):
    errors = []
    for port in created:
        try:
            subprocess.run(['adb', '-s', device, 'reverse', '--remove', f'tcp:{port}'], check=True, stdout=subprocess.DEVNULL)
        except Exception as error:
            errors.append({'port': port, 'error_type': type(error).__name__})
    return errors


def execute(args, output):
    root=Path(__file__).resolve().parents[3]
    flutter=Path('/private/tmp/boohtacord-qa292-flutter')
    sdk='/opt/homebrew/share/android-commandlinetools'
    os.environ.update(ANDROID_HOME=sdk,ANDROID_SDK_ROOT=sdk,JAVA_HOME='/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',DOCKER_CONTEXT='colima-boohtacord-qa')
    os.environ['PATH']=sdk+'/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH','')
    device=args.device or ('emulator-5556' if args.platform=='android' else '82C26E13-0F1F-43F9-AF27-866DC22C2456')
    verify_device(args.platform,device)
    candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    diff_sha=hashlib.sha256(subprocess.check_output(['git','diff','--binary'],cwd=root)).hexdigest()
    manifest=source_manifest(root/'clients/flutter/lib')
    if manifest!=source_manifest(flutter/'lib'): raise ValueError('Independent native app source does not match the reviewed repository')
    qa_paths=['clients/flutter/integration_test/mobile_navigation_qa_test.dart','clients/flutter/test_driver/mobile_navigation_qa.dart','tools/qa/mobile_navigation/run_native.py','tools/qa/mobile_navigation/stack.py','tools/qa/mobile_navigation/os_back.py']
    qa_sources={name:digest(root/name) for name in qa_paths}
    for name in qa_paths[:2]:
        if digest(flutter/Path(name).relative_to('clients/flutter'))!=qa_sources[name]:
            raise ValueError('Independent QA entry or driver source does not match the repository')
    metadata={'candidate':candidate,'dirty_diff_sha256':diff_sha,'qa_source_files':qa_sources,
              'flutter_lib_manifest_sha256':hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest(),
              'app_source_files':{name:manifest[name] for name in ['src/screens/profile_screen.dart','src/screens/workspace_ui/workspace_screen/build/back_guard/handler.dart','src/screens/workspace_ui/workspace_screen/build/swipe_navigation/handler.dart','src/screens/workspace_ui/workspace_screen/build/mobile_layers/handler.dart','src/screens/workspace_ui/main_surface/build/handler.dart','src/screens/workspace_ui/workspace_screen/close_drawers/handler.dart','src/widgets/sliding_drawer_layer.dart','src/features/workspace/search/navigation.dart','src/features/voice/admission/join.dart','src/features/workspace/mobile_navigation/top.dart']},
              'source_copy_match':True,'build_mode':'debug','device':device,
              'os':subprocess.check_output(['adb','-s',device,'shell','getprop','ro.build.version.release'],text=True).strip() if args.platform=='android' else 'iOS27.0 simulator'}
    if args.platform=='android':
        reverses=subprocess.check_output(['adb','-s',device,'reverse','--list'],text=True)
        if any(f'tcp:{p}' in reverses for p in (4840,4844,4893)): raise ValueError('Refusing pre-existing reverse port')
    (output/'runtime.json').write_text(json.dumps(dict(metadata,status='RUNNING',phase='setup'),indent=2)+'\n')
    created_reverses=[]
    stack_removed=True
    report={'status':'FAIL','failed_phase':'native build or execution'}
    completed=False
    from .os_back import AndroidBackBridge
    bridge=AndroidBackBridge(device) if args.platform=='android' else nullcontext()
    try:
        if args.platform=='android':
            install_reverses(device, (4840,4844,4893), created_reverses)
        with tempfile.TemporaryDirectory(prefix='qa292-native-',dir=root/'.out') as temporary:
            stack=Stack(root,Path(temporary))
            try:
                stack_removed=False
                stack.start()
                with socket.create_connection(('127.0.0.1',4840),timeout=5) as plain:
                    with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as secure:
                        pin=hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
                defines=Path(temporary)/'defines.json'
                defines.write_text(json.dumps({'QA_API_BASE':'https://localhost:4840/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password,'QA_CONTROL_BASE':'http://localhost:4844','QA_CONTROL_KEY':bridge.key if args.platform=='android' else ''}))
                defines.chmod(0o600)
                with bridge:
                    run_owned(['flutter','drive','--driver','test_driver/mobile_navigation_qa.dart','--target','integration_test/mobile_navigation_qa_test.dart','-d',device,'--dart-define-from-file',str(defines)],cwd=flutter,env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(output)),timeout=1200)
                completed=True
            finally:
                stack.close()
                stack_removed=True
    finally:
        cleanup_errors=remove_reverses(device, created_reverses)

        if (output/'scenario.json').exists():report=json.loads((output/'scenario.json').read_text())
        if not completed or cleanup_errors or not stack_removed:report['status']='FAIL'
        report.update(metadata,android_OS_Back_dispatches=bridge.count if args.platform=='android' else 0,owned_resources_removed=stack_removed and not cleanup_errors,owned_reverse_ports_created=created_reverses,owned_reverse_removed=not cleanup_errors,reverse_cleanup_errors=cleanup_errors,screenshots={p.name:digest(p) for p in output.glob('*.png')})
        if completed:
            artifact=flutter/'build/app/outputs/flutter-apk/app-debug.apk' if args.platform=='android' else flutter/'build/ios/iphonesimulator/Runner.app/Runner'
            report['native_artifact_sha256']=digest(artifact)
        (output/'runtime.json').write_text(json.dumps(report,indent=2)+'\n')
        if cleanup_errors:raise RuntimeError('Owned reverse cleanup failed')
    assert report['status'] in ('PASS','PARTIAL') and report.get('checks') and all(value=='PASS' for value in report['checks'].values()), 'Native mobile-navigation scenario did not pass its observed checks'
    assert len(report['screenshots'])>=4,'Native visual evidence missing'
    print('#292 '+args.platform+' observed rows passed; remaining issue gates PARTIAL; owned resources removed',flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--platform',choices=['android','ios'],default='android')
    parser.add_argument('--device')
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    output=root/'.out/qa292-20261012'/args.platform
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
