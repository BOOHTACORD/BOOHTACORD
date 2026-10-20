"""Native receiver for an already-running owned #247 API/SFU/publisher."""
import argparse
import hashlib
import json
import os
import socket
import ssl
import subprocess
import tempfile
import secrets
from datetime import datetime, timezone
from pathlib import Path
from tools.qa.guild_identity.run import current_identity
from tools.qa.local_features.native import verify_device
from .bridge import PublisherBridge
from .environment import native_environment


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_manifest(directory):
    files={str(p.relative_to(directory)):digest(p) for p in sorted(directory.rglob('*')) if p.is_file()}
    return hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest(),len(files)


def archive_previous(output):
    files=list(output.glob('*.png'))+[p for p in (output/'scenario.json',output/'runtime.json') if p.exists()]
    if files:
        archive=output.parent/'previous-attempts'/output.name/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        archive.mkdir(parents=True)
        for p in files:p.rename(archive/p.name)


REQUIRED_CHECKS = (
    'automatic_TEXT_DM_settings_one_output_no_resubscription',
    'full_mini_full_return_preserves_stream',
    'stop_two_publications_exactly_once_and_mute', 'automatic_route_retention_and_explicit_stop',
    'viewport_320_adaptive_keyboard_labels', 'source_removal_cleanup',
    'disconnect_cleanup', 'logout_account_switch_cleanup', 'revoke_cleanup',
)


def validated_outcome(path, required=REQUIRED_CHECKS):
    value=json.loads(path.read_text())
    if value.get('status')!='PASS' or any(value.get('checks',{}).get(k)!='PASS' for k in required):
        raise RuntimeError('Native acceptance has incomplete or failed required checks')
    return value


def verify_owned_device(platform, device):
    expected = 'emulator-5558' if platform == 'android' else '57E6A791-8975-4C84-82E6-47321F22C9B8'
    if device != expected:
        raise ValueError('Device is not assigned to mini-player QA')
    if platform == 'android':
        name = subprocess.check_output(['adb', '-s', device, 'emu', 'avd', 'name'], text=True).splitlines()[0].strip()
        if name != 'BOOHTACORD_QA_278_API35':
            raise ValueError('Assigned Android serial has a different AVD')
    else:
        devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
        matches = [v for values in devices['devices'].values() for v in values if v['udid'] == device]
        if len(matches) != 1 or matches[0]['name'] != 'BOOHTACORD QA278 iPhone':
            raise ValueError('Assigned iOS UUID has a different simulator')
    verify_device(platform, device)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--platform',choices=['android','ios'],required=True)
    parser.add_argument('--device',required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    os.environ.update(native_environment(os.environ))
    output=root/'.out/qa247-20261012'/args.platform;output.mkdir(parents=True,exist_ok=True);archive_previous(output)
    report={'issue':247,'status':'RUNNING','phase':'preflight','platform':args.platform,'started_at':datetime.now(timezone.utc).isoformat(),'runtime_completed':False,'owned_reverse_removed':False}
    receipt=output/'runtime.json'
    def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
    save()
    private=Path('/private/tmp/boohtacord-qa247-flutter');reversed_ports=[];ports=(4830,4884,4834);build_started=False
    try:
        report.update(current_identity(root))
        report['qa_handler_sha256']={name:digest(root/'tools/qa/mini_player'/name) for name in ('native.py','bridge.py','scenario.mjs','environment.py')}
        report['qa_driver_sha256']=digest(root/'clients/flutter/test_driver/mini_player_qa.dart')
        holder=json.loads((root/'.out/qa247-20261012/web/results.json').read_text())
        if holder.get('status') != 'PASS':
            raise RuntimeError('Publisher browser acceptance must finish before native source control')
        report['actual_publisher_handler']=holder.get('publisher_bridge_handler')
        if report['actual_publisher_handler'] != {'scenario_sha256':report['qa_handler_sha256']['scenario.mjs'],'protocol':'live-string-atomic-ui-v2'}:
            raise RuntimeError('Fresh publisher with current tested handler is required')
        save()
        inputs=json.loads(Path((root/'.out/qa247-20261012/active-input-path').read_text()).read_text())
        source=subprocess.check_output(['docker','exec',inputs['owner']+'-db','psql','-U','qa','-d','qa','-tAc',"SELECT id FROM users WHERE login='qa_screen_source'"],text=True).strip()
        if not source:raise ValueError('Own actual publisher is required')
        with socket.create_connection(('127.0.0.1',4830)) as plain:
            with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as tls:
                pin=hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
        verify_owned_device(args.platform,args.device)
        if args.platform=='android':
            old=subprocess.check_output(['adb','-s',args.device,'reverse','--list'],text=True)
            if any('tcp:'+str(p) in old for p in ports):raise ValueError('Reverse already owned by another run')
            for p in ports:
                subprocess.run(['adb','-s',args.device,'reverse','tcp:'+str(p),'tcp:'+str(p)],check=True,stdout=subprocess.DEVNULL);reversed_ports.append(p)
        report['phase']='source copy';save()
        subprocess.run(['rsync','-a','--delete','--exclude','/build','--exclude','/.dart_tool','--exclude','/ios/Pods','--exclude','/ios/.symlinks',str(root/'clients/flutter')+'/',str(private)+'/'],check=True)
        actual,count=source_manifest(private/'lib');expected,_=source_manifest(root/'clients/flutter/lib')
        if actual!=expected:raise RuntimeError('Private source copy differs from shared candidate')
        report.update(flutter_lib_sha256=actual,flutter_lib_file_count=count,qa_target_sha256=digest(private/'integration_test/mini_player_qa_test.dart'))
        # A failed compilation must not inherit the previous executable's hash.
        executable=private/('build/app/outputs/flutter-apk/app-debug.apk' if args.platform=='android' else 'build/ios/iphonesimulator/Runner.app/Runner')
        executable.unlink(missing_ok=True);build_started=True
        report['phase']='native drive';save();bridge_secret=secrets.token_urlsafe(32)
        with tempfile.TemporaryDirectory(prefix='qa247-native-',dir='/private/tmp') as temporary:
            defines=Path(temporary)/'defines.json';defines.write_text(json.dumps({'QA_API_BASE':'https://localhost:4830/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':inputs['password'],'QA_SOURCE_ACCOUNT':source,'QA_NATIVE_LOGIN':'qa_mini_'+args.platform,'QA_BRIDGE_CONTROL':bridge_secret}));defines.chmod(0o600)
            with PublisherBridge(output.parent,bridge_secret):
                subprocess.run(['flutter','drive','--driver','test_driver/mini_player_qa.dart','--target','integration_test/mini_player_qa_test.dart','-d',args.device,'--dart-define-from-file',str(defines)],cwd=private,
                    env=dict(os.environ,BOOHTACORD_NATIVE_CAPTURE_DIR=str(output)),check=True,timeout=1500)
        report['runtime_completed']=True
        scenario=validated_outcome(output/'scenario.json');report.update(scenario)
        if scenario.get('status')!='PASS':raise RuntimeError('Native mini player scenario failed')
        report['status']='PASS';report['phase']='complete'
    except Exception as error:
        report.update(status='FAIL',error_type=type(error).__name__,error_phase=report.get('phase'))
        scenario_path=output/'scenario.json'
        if scenario_path.exists():
            scenario=json.loads(scenario_path.read_text());report.update(scenario);report['status']='FAIL'
        raise
    finally:
        cleanup_errors=[]
        for p in reversed_ports:
            try:subprocess.run(['adb','-s',args.device,'reverse','--remove','tcp:'+str(p)],check=True,stdout=subprocess.DEVNULL)
            except Exception as error:cleanup_errors.append(type(error).__name__)
        if cleanup_errors:report.update(status='FAIL',cleanup_errors=cleanup_errors)
        report.update(owned_reverse_removed=not cleanup_errors,completed_at=datetime.now(timezone.utc).isoformat(),build_mode='debug',device_kind='emulator' if args.platform=='android' else 'simulator',
            screenshots={p.name:digest(p) for p in output.glob('*.png')})
        executable=private/('build/app/outputs/flutter-apk/app-debug.apk' if args.platform=='android' else 'build/ios/iphonesimulator/Runner.app/Runner')
        report['native_executable_sha256']=digest(executable) if build_started and executable.exists() else None
        save()
        if cleanup_errors:raise RuntimeError('Owned reverse cleanup failed')


if __name__=='__main__':main()
