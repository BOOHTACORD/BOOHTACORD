"""Original legacy EXE -> current real per-user installation, on disposable CI only."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
from tools.ci.native.process import ROOT, output
from tools.qa.desktop_updates.windows_process import close_owned, running_at
from .packages import BASELINE, read_policy, release_files, verify_files
from .policy import require_hosted, target, validate_observation
from .owned import scope


def observe(executable, mode, release, destination):
    processes = running_at(executable)
    if not processes:
        subprocess.Popen([str(executable)],cwd=executable.parent,
                         stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        deadline=time.monotonic()+15
        while not (processes:=running_at(executable)) and time.monotonic()<deadline: time.sleep(.25)
    if len(processes)!=1: raise RuntimeError('Exactly one owned native process required')
    subprocess.run(['powershell.exe','-NoProfile','-NonInteractive',
        '-File',str(Path(__file__).with_name('observe.ps1')),'-ClientProcess',str(processes[0]),
        '-Mode',mode,'-Version',BASELINE if mode=='old' else release['version'],
        '-Build','46' if mode=='old' else release['native_build'],
        '-TargetVersion',release['version'],'-Summary',release['summary'],'-Output',str(destination)],
        check=True,timeout=100,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    row=json.loads((destination/(mode+'.json')).read_text(encoding='utf-8-sig'))
    validate_observation(row,mode,release)
    return row


def main():
    require_hosted(os.environ,sys.platform)
    profile=Path(os.environ['APPDATA'])/'ru.boohtacord/boohtacord_desktop'
    if profile.exists() or (Path(os.environ['LOCALAPPDATA'])/'boohtacord_desktop').exists():
        raise RuntimeError('Refusing a pre-existing app/profile on this runner')
    destination=ROOT/'.out/legacy-windows-update'
    destination.mkdir(parents=True,exist_ok=False)
    report={'status':'FAIL','source_revision':output('git','rev-parse','HEAD'),
            'windows':platform.version(),'production_mutations':False,'user_machine':False,
            'current_ui_scope':'visible version and no incorrect offer; authenticated settings NOT_RUN'}
    with scope(Path(os.environ['RUNNER_TEMP']),report,destination/'result.json') as root:
        baseline=root/'baseline/boohtacord_desktop.exe'
        installed=root/'installed/current/boohtacord_desktop.exe'
        try:
            document=read_policy(); release=target(document)
            report['catalog_before']=document
            _,old,old_hash=release_files(root,BASELINE,baseline=True)
            verify_files(baseline.parent,old)
            setup,new,new_hash=release_files(root,release['version'])
            if new['version'] != release['version']+'+'+release['native_build'] or new['release_id'] != release['release_id']:
                raise ValueError('Published package differs from live catalog')
            report.update(old_manifest_sha256=old_hash,current_manifest_sha256=new_hash)
            report['old']=observe(baseline,'old',release,destination)
            close_owned(baseline)
            subprocess.run([str(setup),'--silent','--installto',str(root/'installed')],
                           check=True,timeout=120,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            if not (root/'installed/Update.exe').is_file(): raise RuntimeError('Real per-user install missing')
            verify_files(installed.parent,new)
            report['current']=observe(installed,'current',release,destination)
            verify_files(installed.parent,new)
            report['catalog_after']=read_policy()
            if report['catalog_after']!=document: raise RuntimeError('Public target changed during acceptance')
            report['status']='PASS'
        finally:
            try:
                for executable in (baseline,installed):
                    if executable.exists(): close_owned(executable)
                updater=root/'installed/Update.exe'
                if updater.exists():
                    subprocess.run([str(updater),'--uninstall','--silent'],check=True,timeout=60,
                                   stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                report['owned_processes_closed']=True
            except Exception:
                report['status']='FAIL';report['owned_processes_closed']=False
                raise
    print('Original old Windows client and installed stable update acceptance PASS')


if __name__=='__main__': main()
