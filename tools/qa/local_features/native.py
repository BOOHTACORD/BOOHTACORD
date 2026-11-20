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
from .update_catalog import write_catalog
from .android_back.exercise import android_back_on_capture
from .android_microphone import android_microphone_permission

DEFAULT_ISSUE785_BACKGROUND_SECONDS = 120

def native_target(target):
    scopes = {
        'integration_test/local_qa_test.dart': 'auth, authenticated workspace, profile/audio/admin panels, logout',
        'integration_test/issue689_roster_test.dart': 'auth, public/auth maintenance handoff, synthetic unknown banner, voice roster socket and manual reconnect',
        'integration_test/issue689_listener_test.dart': 'real SFU listener, roster and app socket recovery; no microphone capture',
        'integration_test/issue786_deafen_test.dart': 'authenticated voice lease updates the replicated deafen attribute and v2 roster; no microphone capture or paired media claim',
        'integration_test/android_noise_sfu_test.dart': 'Android RNNoise microphone capture in an owned LiveKit room; physical acoustic quality not tested',
        'integration_test/issue785_background_listener_pair_test.dart': 'paired Flutter Android listener-only session with synthetic sender; checks mediaPlayback FGS and receiver counters, not physical audibility',
        'integration_test/issue689_delivery_revocation_test.dart': 'native revocation delivery under synthetic backlog; no actual socket pressure',
        'integration_test/issue689_heartbeat_test.dart': 'native silent socket recovery against loopback; no real network switching or media',
        'integration_test/issue689_envelope_test.dart': 'native malformed maintenance envelope recovery against loopback; no real network switching or media',
        'integration_test/issue689_topology_history_test.dart': 'native topology history response held across socket close against owned API',
        'integration_test/update_required_test.dart': 'required update gate from real synthetic catalog on owned API; no installer launch',
    }
    if target not in scopes: raise ValueError('Unsupported native QA target')
    return scopes[target]


def validate_issue785_background_seconds(seconds):
    if seconds < 120:
        raise ValueError('Issue 785 listener playback QA must run for at least 120 seconds')
    return seconds


def remove_generated_android_plugin_registrant(root):
    generated = (Path(root) / 'clients/flutter/android/app/src/main/java/io/flutter/plugins'
                 / 'GeneratedPluginRegistrant.java')
    try:
        generated.unlink()
    except FileNotFoundError:
        pass


def verify_device(platform, device):
    if platform == 'windows':
        if device != 'windows': raise ValueError('Select the Windows desktop target')
        records=json.loads(subprocess.check_output(['flutter','devices','--machine'],text=True))
        if not any(row.get('id')=='windows' and row.get('targetPlatform')=='windows-x64'
                   and row.get('isSupported') is True for row in records):
            raise ValueError('Supported Windows desktop target is unavailable')
    elif platform == 'ios':
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
    parser.add_argument('--platform',required=True,choices=['android','ios','windows'])
    parser.add_argument('--device',required=True)
    parser.add_argument('--output',required=True)
    parser.add_argument('--target',default='integration_test/local_qa_test.dart')
    args=parser.parse_args()
    if args.target == 'integration_test/issue785_background_listener_pair_test.dart' and args.platform != 'android':
        raise ValueError('Issue 785 listener playback integration is Android-only')
    if args.platform=='windows' and args.target!='integration_test/issue689_roster_test.dart':
        raise ValueError('Windows QA is restricted to the isolated issue689 scenario')
    scope=native_target(args.target)
    verify_device(args.platform,args.device)
    root=Path(__file__).resolve().parents[3]
    destination=Path(args.output).resolve();destination.mkdir(parents=True,exist_ok=True)
    if args.target == 'integration_test/issue785_background_listener_pair_test.dart':
        seconds = int(os.environ.get(
            'BOOHTACORD_ISSUE785_BACKGROUND_SECONDS',
            str(DEFAULT_ISSUE785_BACKGROUND_SECONDS),
        ))
        validate_issue785_background_seconds(seconds)
        run_owned(
            ['python3', '-m', 'tools.qa.critical_client_acceptance.issue785_android_flutter_background_pair',
             '--device', args.device, '--background-seconds', str(seconds),
             '--output', str(destination)],
            cwd=root,
            env=dict(os.environ),
            timeout=seconds + 300,
        )
        result = json.loads((destination / 'result.json').read_text(encoding='utf8'))
        (destination / 'runtime.json').write_text(json.dumps({
            'status': result['status'],
            'platform': 'android',
            'device': args.device,
            'physical_device': False,
            'media': result['media_result'],
            'playback_foreground_service_active': result['scenario']['playback_foreground_service_active'],
            'microphone_foreground_service_active': result['scenario']['microphone_foreground_service_active'],
            'background_seconds_observed': result['scenario']['background_seconds_observed'],
            'scope': native_target(args.target),
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
        return
    local_api('https://localhost:4810/api/v1')
    with reversed_ports(args.device) if args.platform=='android' else nullcontext():
        with tempfile.TemporaryDirectory(prefix='native-qa-',dir=root/'.out') as temporary:
            work=Path(temporary); stack=Stack(root,work)
            if args.target == 'integration_test/update_required_test.dart':
                build=json.loads((root/'contracts/client-build.json').read_text(encoding='utf8'))
                stack.qa_update_catalog=write_catalog(work, build['builds'][args.platform]['release_order'])
                stack.environment['CLIENT_UPDATE_CATALOG_PATH']='/qa-client-update/catalog.json'
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
                with android_back_on_capture(args.platform,args.device,args.target,destination), android_microphone_permission(args.platform,args.device,args.target):
                    try:
                        run_owned(['flutter','drive','--driver','test_driver/local_qa.dart',
                            '--target',args.target,'-d',args.device,
                            '--dart-define-from-file',str(defines)],cwd=root/'clients/flutter',
                            env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(destination)),timeout=1200)
                    finally:
                        if args.platform == 'android':
                            remove_generated_android_plugin_registrant(root)
                (destination/'runtime.json').write_text(json.dumps({'status':'PASS','platform':args.platform,
                    'device':args.device,'mocks':args.platform=='windows','scope':scope,
                    'mocked_components':['preferences','secure_storage'] if args.platform=='windows' else [],
                    'media':'NOT_RUN','physical_device':args.platform=='windows',
                    'android_back':'PASS' if args.platform=='android' and args.target=='integration_test/update_required_test.dart' else 'NOT_RUN'},indent=2)+'\n')
            finally: stack.close()

if __name__=='__main__':main()
