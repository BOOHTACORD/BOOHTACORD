"""Owned #295/#298 native production widgets, real API/SFU and fresh receipts."""
import argparse
import hashlib
import json
import os
import shutil
import socket
import ssl
import subprocess
import tempfile
import time
from pathlib import Path
from .policy import assigned_device, ANDROID, IOS
from .stack import Stack
from tools.qa.local_features.process import run_owned

ROOT=Path(__file__).resolve().parents[3]
FLUTTER=Path('/private/tmp/boohtacord-qa295298-flutter')

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def manifest(path):return {str(p.relative_to(path)):digest(p) for p in sorted(path.rglob('*.dart'))}

def remove_reverses(device,created):
    errors=[]
    for port in created:
        try:subprocess.run(['adb','-s',device,'reverse','--remove',f'tcp:{port}'],check=True,stdout=subprocess.DEVNULL)
        except Exception as error:errors.append({'port':port,'error_type':type(error).__name__})
    return errors

def prepare():
    if FLUTTER.exists():
        if not (FLUTTER/'.qa295298-owned').exists():raise ValueError('Refusing a foreign native copy')
        return
    source=ROOT/'clients/flutter'
    generated={'build','.dart_tool','.git','android/.gradle','ios/Pods','ios/.symlinks','macos/Pods','macos/.symlinks','ios/Flutter/ephemeral','macos/Flutter/ephemeral','windows/flutter/ephemeral','linux/flutter/ephemeral'}
    def ignore(directory,names):
        base=Path(directory).relative_to(source)
        return [name for name in names if (base/name).as_posix() in generated]
    shutil.copytree(source,FLUTTER,ignore=ignore)
    (FLUTTER/'.qa295298-owned').write_text('owned disposable QA source copy\n')
    FLUTTER.chmod(0o700)

def execute(platform,output):
    sdk='/opt/homebrew/share/android-commandlinetools'
    os.environ.update(ANDROID_HOME=sdk,ANDROID_SDK_ROOT=sdk,JAVA_HOME='/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',DOCKER_CONTEXT='colima-boohtacord-qa')
    os.environ['PATH']=sdk+'/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH','')
    device=ANDROID if platform=='android' else IOS
    assigned_device(platform,device)
    prepare()
    source=manifest(ROOT/'clients/flutter/lib')
    if source!=manifest(FLUTTER/'lib'):raise ValueError('Native app source copy differs from reviewed source')
    qa=['integration_test/admin_dialogs_qa_test.dart','test_driver/admin_dialogs_qa.dart']
    for name in qa:
        if digest(ROOT/'clients/flutter'/name)!=digest(FLUTTER/name):raise ValueError('Native QA entry copy changed')
    report={'status':'RUNNING','phase':'setup','candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
      'flutter_lib_manifest_sha256':hashlib.sha256(json.dumps(source,sort_keys=True).encode()).hexdigest(),
      'qa_sources':{name:digest(FLUTTER/name) for name in qa},'build_mode':'debug','physical_device':False,'owned_resources_removed':False}
    (output/'runtime.json').write_text(json.dumps(report,indent=2)+'\n')
    created=[];completed=False;stack=None;cleanup_errors=[]
    try:
        if platform=='android':
            existing=subprocess.check_output(['adb','-s',device,'reverse','--list'],text=True).split()
            if any(f'tcp:{p}' in existing for p in (4950,4991)):raise ValueError('Assigned reverse port already exists')
            for port in (4950,4991):
                subprocess.run(['adb','-s',device,'reverse',f'tcp:{port}',f'tcp:{port}'],check=True,stdout=subprocess.DEVNULL);created.append(port)
        with tempfile.TemporaryDirectory(prefix='qa295298-native-',dir=ROOT/'.out') as temporary:
            work=Path(temporary);work.chmod(0o700);stack=Stack(ROOT,work)
            try:
                stack.start()
                with socket.create_connection(('127.0.0.1',4950),timeout=5) as plain:
                    with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as secure:
                        pin=hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
                defines=work/'defines.json'
                defines.write_text(json.dumps({'QA_API_BASE':'https://localhost:4950/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password}));defines.chmod(0o600)
                # Private raw build/driver output is never publication evidence and is removed with the stack workdir.
                with (work/'driver-private.log').open('w') as log:
                    run_owned(['flutter','drive','--driver','test_driver/admin_dialogs_qa.dart','--target','integration_test/admin_dialogs_qa_test.dart','-d',device,'--dart-define-from-file',str(defines)],cwd=FLUTTER,env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(output)),stdout=log,stderr=subprocess.STDOUT,timeout=1200)
                completed=True
                artifact=FLUTTER/'build/app/outputs/flutter-apk/app-debug.apk' if platform=='android' else FLUTTER/'build/ios/iphonesimulator/Runner.app/Runner'
                report['native_artifact_sha256']=digest(artifact)
            finally:
                try:stack.close()
                except Exception as error:cleanup_errors.append({'scope':'stack','error_type':type(error).__name__})
    finally:
        if platform=='android':cleanup_errors+=remove_reverses(device,created)
        if (output/'scenario.json').exists():report.update(json.loads((output/'scenario.json').read_text()))
        if not completed:report['status']='FAIL'
        if cleanup_errors:report.update(status='FAIL',cleanup_errors=cleanup_errors)
        report.update(owned_resources_removed=not cleanup_errors and stack is not None and not stack.resources,
          screenshots={p.name:digest(p) for p in output.glob('*.png')})
        (output/'runtime.json').write_text(json.dumps(report,indent=2)+'\n')
    if not completed or cleanup_errors or report.get('status') not in ('PASS','PARTIAL'):raise RuntimeError('Native scenario failed; consult sanitized receipt')
    if not report.get('checks') or any(v!='PASS' for v in report['checks'].values()):raise RuntimeError('Incomplete observed native rows')
    print(f'#295/#298 {platform}: observed native rows passed; hardware/reader gates remain NOT_RUN',flush=True)

def run(platform,output):
    output.mkdir(parents=True,exist_ok=True)
    previous=output.parent/'previous-harness-runs'/platform/str(time.time_ns())
    if any(output.iterdir()):
        previous.mkdir(parents=True)
        for path in output.iterdir():
            if path.is_file():path.rename(previous/path.name)
    receipt=output/'runtime.json';report={'status':'RUNNING','phase':'preflight','platform':platform,'owned_resources_removed':False}
    receipt.write_text(json.dumps(report,indent=2)+'\n')
    try:execute(platform,output)
    except BaseException as error:
        try:report=json.loads(receipt.read_text())
        except (OSError,ValueError):pass
        report.update(status='FAIL',error_type=type(error).__name__)
        receipt.write_text(json.dumps(report,indent=2)+'\n');raise

def main():
    p=argparse.ArgumentParser();p.add_argument('--platform',choices=['android','ios'],required=True);args=p.parse_args()
    run(args.platform,ROOT/'.out/qa295298-20261012'/args.platform)
if __name__=='__main__':main()
