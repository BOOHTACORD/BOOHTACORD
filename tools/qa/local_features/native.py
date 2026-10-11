"""Run the native production widgets against the owned real API on a QA simulator."""
import argparse
from contextlib import contextmanager, nullcontext
import hashlib
import json
import os
import socket
import ssl
import subprocess
import tempfile
from pathlib import Path
from .stack import Stack
from .policy import local_api
from .process import run_owned


def verify_device(platform, device):
    if platform == 'ios':
        records=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))
        match=[d for values in records['devices'].values() for d in values if d['udid']==device]
        if not match or not match[0]['name'].startswith('BOOHTACORD QA'):
            raise ValueError('Select the dedicated BOOHTACORD QA iOS Simulator')
        if match[0]['state']!='Booted':
            subprocess.run(['xcrun','simctl','boot',device],check=True)
        subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True)
    else:
        if not device.startswith('emulator-'): raise ValueError('Android QA needs a dedicated emulator')
        name=subprocess.check_output(['adb','-s',device,'emu','avd','name'],text=True).splitlines()[0]
        if not name.startswith('BOOHTACORD_QA'): raise ValueError('Select the dedicated BOOHTACORD_QA AVD')


@contextmanager
def reversed_ports(device):
    ports=(4810,4881)
    existing=subprocess.check_output(['adb','-s',device,'reverse','--list'],text=True).split()
    if any('tcp:'+str(port) in existing for port in ports):
        raise ValueError('An existing QA port reverse belongs to another run')
    created=[]
    try:
        for port in ports:
            endpoint='tcp:'+str(port)
            subprocess.run(['adb','-s',device,'reverse',endpoint,endpoint],check=True)
            created.append(endpoint)
        yield
    finally:
        for endpoint in reversed(created):
            subprocess.run(['adb','-s',device,'reverse','--remove',endpoint],check=False)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--platform',required=True,choices=['android','ios'])
    parser.add_argument('--device',required=True)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    verify_device(args.platform,args.device)
    root=Path(__file__).resolve().parents[3]
    destination=Path(args.output).resolve();destination.mkdir(parents=True,exist_ok=True)
    local_api('https://localhost:4810/api/v1')
    with reversed_ports(args.device) if args.platform=='android' else nullcontext():
        with tempfile.TemporaryDirectory(prefix='native-qa-',dir=root/'.out') as temporary:
            work=Path(temporary); stack=Stack(root,work)
            try:
                stack.start()
                ctx=ssl._create_unverified_context()
                with socket.create_connection(('127.0.0.1',4810),timeout=5) as plain:
                    with ctx.wrap_socket(plain,server_hostname='localhost') as secure:
                        pin=hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
                defines=work/'defines.json'
                defines.write_text(json.dumps({'QA_API_BASE':'https://localhost:4810/api/v1',
                                               'QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password}))
                defines.chmod(0o600)
                run_owned(['flutter','drive','--driver','test_driver/local_qa.dart',
                    '--target','integration_test/local_qa_test.dart','-d',args.device,
                    '--dart-define-from-file',str(defines)],cwd=root/'clients/flutter',
                    env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(destination)),timeout=1200)
                (destination/'runtime.json').write_text(json.dumps({'status':'PASS','platform':args.platform,
                    'device':args.device,'mocks':False,'scope':'auth, authenticated workspace, profile/audio/admin panels, logout',
                    'media':'NOT_RUN','physical_device':False},indent=2)+'\n')
            finally: stack.close()

if __name__=='__main__':main()
