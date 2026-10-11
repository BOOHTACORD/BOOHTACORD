import json
import shutil
import subprocess
import time


def probe(command):
    try:
        result=subprocess.run(command,text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=30)
        return result.stdout.strip() if result.returncode==0 else None
    except (OSError,subprocess.TimeoutExpired):return None


def devices():
    result={}
    data=probe(['xcrun','simctl','list','devices','--json'])
    if data:
        for group in json.loads(data)['devices'].values():
            for device in group:
                if device.get('isAvailable') and device['name'].startswith('BOOHTACORD QA'):
                    result['ios']=device['udid'];break
    data=probe(['adb','devices'])
    if data:
        for line in data.splitlines()[1:]:
            if '\tdevice' not in line:continue
            serial=line.split()[0]
            name=probe(['adb','-s',serial,'emu','avd','name']) if serial.startswith('emulator-') else None
            if name and name.startswith('BOOHTACORD_QA'):result['android']=serial;break
    return result


def boot_android(log):
    available=probe(['emulator','-list-avds']) or ''
    owned=[name for name in available.splitlines() if name.startswith('BOOHTACORD_QA')]
    if not owned:return None
    try:
        with log.open('w') as output:
            subprocess.Popen(['emulator','-avd',owned[0],'-no-snapshot','-no-boot-anim'],
                             stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
    except OSError:return None
    for _ in range(120):
        ready=devices().get('android')
        if ready:return ready
        time.sleep(1)
    return None


def main():
    checks={name:bool(shutil.which(name)) for name in ['node','npm','flutter','docker','adb','xcrun']}
    checks['docker_runtime']=bool(probe(['docker','info','--format','{{.ServerVersion}}']))
    print(json.dumps({'tools':checks,'qa_devices':devices()},indent=2))
    return 0 if all(checks.values()) else 1

if __name__=='__main__':raise SystemExit(main())
