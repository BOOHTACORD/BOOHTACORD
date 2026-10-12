"""Owned-device and fresh-receipt validation for DM/composer acceptance."""
import json
import subprocess
from datetime import datetime,timezone
from pathlib import Path

def archive_previous(output):
    files=[p for p in Path(output).iterdir() if p.is_file()]
    if files:
        archive=Path(output).parent/'previous-attempts'/Path(output).name/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        archive.mkdir(parents=True)
        for path in files:path.rename(archive/path.name)

def validate_report(value, required):
    if value.get('status')!='PASS' or not required or any(value.get('checks',{}).get(key)!='PASS' for key in required):
        raise ValueError('Required observed acceptance rows missing or failed')
    return value

def validate_device(platform,device):
    expected='emulator-5556' if platform=='android' else '82C26E13-0F1F-43F9-AF27-866DC22C2456'
    if device!=expected:raise ValueError('Device is not assigned to QA294')
    if platform=='android':
        name=subprocess.check_output(['adb','-s',device,'emu','avd','name'],text=True).splitlines()[0].strip()
        if name!='BOOHTACORD_QA_283_API35':raise ValueError('Assigned serial is a different AVD')
    else:
        devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))
        matches=[d for values in devices['devices'].values() for d in values if d['udid']==device]
        if len(matches)!=1 or not matches[0]['name'].startswith('BOOHTACORD QA'):raise ValueError('Assigned UUID is a different simulator')
    from tools.qa.local_features.native import verify_device
    verify_device(platform,device)
