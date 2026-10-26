"""Reproducible local evidence, separate from physical/provider acceptance."""
import argparse
import datetime
import json
import platform
import shutil
import subprocess
import time
from .profiles import ROOT, execute
from .source import identity

PROFILES = ('backend','contracts','web','flutter','flutter-vendor','queries')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--profile',choices=PROFILES,action='append')
    parser.add_argument('--promtool')
    args=parser.parse_args()
    destination=ROOT/'.out/notification-acceptance';destination.mkdir(parents=True,exist_ok=True)
    result={};failed=False
    for profile in args.profile or PROFILES:
        row={**identity(ROOT),'status':'FAIL','host':platform.platform(),'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'evidence_level':'local_only','physical_provider_delivery':'NOT_RUN'}
        started=time.monotonic()
        with (destination/(profile+'.log')).open('w',encoding='utf-8') as log:
            def run(command,cwd):
                executable=shutil.which(command[0])
                if executable is None:raise FileNotFoundError(command[0])
                command=[executable,*command[1:]]
                log.write('COMMAND '+json.dumps(command)+'\n');log.flush()
                subprocess.run(command,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
            try:
                execute(profile,run,args.promtool)
                if identity(ROOT)['source_snapshot_sha256']!=row['source_snapshot_sha256']:raise RuntimeError('Source changed during local profile')
                row['status']='PASS'
            except (OSError,subprocess.TimeoutExpired) as error:
                row.update(status='BLOCKED',reason=type(error).__name__);failed=True
            except subprocess.CalledProcessError as error:
                row.update(status='FAIL',exit_code=error.returncode);failed=True
            except RuntimeError as error:
                row.update(status='FAIL',reason=str(error));failed=True
        row['seconds']=time.monotonic()-started
        result[profile]=row
        (destination/(profile+'.json')).write_text(json.dumps(row,indent=2)+'\n',encoding='utf-8')
        print(profile+'='+row['status'],flush=True)
    if failed:raise SystemExit(1)

if __name__=='__main__':main()
