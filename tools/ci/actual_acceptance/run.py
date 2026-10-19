"""Run the original real controllers with deadlines, source and cleanup evidence."""
import argparse
import fcntl
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import time
from tools.ci.native.process import ROOT,output
from tools.qa.local_features.process import stop_group
from . import catalog,session
from .plan import PROFILES,require,document
from .evidence import collect


def execute(profile,baseline):
    public=ROOT/'.out/actual-acceptance/public'/profile
    public.mkdir(parents=True,exist_ok=False)
    report={'schema_version':1,'status':'FAIL','scope':'automatic-PR-real-runtime','profile':profile,
            'physical_acceptance':'NOT_RUN','release_acceptance':'NOT_RUN','owned_resources_removed':False,'operations':[]}
    child=None;owner=None;lease=None;old_signal=None;started=time.monotonic()
    try:
        session.hosted()
        source=output('git','rev-parse','HEAD');require(source==os.environ.get('GITHUB_SHA') and re.fullmatch('[0-9a-f]{40}',baseline))
        subprocess.run(['git','diff','--exit-code','HEAD','--'],cwd=ROOT,stdout=subprocess.DEVNULL,check=True)
        for relative in catalog.ROOTS[profile]:require(not (ROOT/relative).exists())
        private=ROOT/'.out/actual-acceptance/private';private.mkdir(parents=True,exist_ok=True,mode=0o700)
        lock=private/'host.lock';lease=lock.open('a');fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB)
        row=session.identity(source,profile,os.environ);owner=row['owner'];report.update(row,map_sha256=document()[1])
        def terminate(*_):raise InterruptedError('Owned actual acceptance interrupted')
        old_signal=signal.signal(signal.SIGTERM,terminate)
        env=session.child_environment(row)
        log=private/(profile+'.log')
        with log.open('xb') as stream:
            log.chmod(0o600)
            for index,command in enumerate(catalog.OPERATIONS[profile]):
                args=[baseline if arg=='BASELINE' else arg for arg in command]
                operation_started=time.monotonic();report['operation']=index
                child=subprocess.Popen(args,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
                while child.poll() is None:
                    if time.monotonic()-started>catalog.LIMITS[profile] or log.stat().st_size>16_000_000:
                        raise TimeoutError('Bounded actual runtime exceeded its budget')
                    time.sleep(.1)
                require(child.returncode==0);child=None
                report['operations'].append({'index':index,'seconds':round(time.monotonic()-operation_started,3)})
        require(output('git','rev-parse','HEAD')==source)
        subprocess.run(['git','diff','--exit-code','HEAD','--'],cwd=ROOT,stdout=subprocess.DEVNULL,check=True)
        report.update(collect(ROOT,profile,source,public),status='PASS')
    except BaseException as error:
        report.update(status='BLOCKED' if owner is None else 'FAIL',failure_type=type(error).__name__)
        raise
    finally:
        try:
            if child is not None:stop_group(child)
        except BaseException:
            report.update(status='FAIL',failure_type='ProcessCleanupFailed')
        try:
            if owner:
                report['owned_resources_removed']=session.cleanup(owner)
                require(report['owned_resources_removed'] is True)
        except BaseException:
            report.update(status='FAIL',owned_resources_removed=False,failure_type='CleanupFailed')
        if old_signal is not None:signal.signal(signal.SIGTERM,old_signal)
        if lease is not None:lease.close()
        report['seconds']=round(time.monotonic()-started,3)
        (public/'result.json').write_text(json.dumps(report,sort_keys=True)+'\n',encoding='utf-8')
        if report['status']!='PASS':raise SystemExit('Actual acceptance failed or blocked: '+profile)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--profile',choices=PROFILES,required=True)
    parser.add_argument('--baseline',required=True);args=parser.parse_args();execute(args.profile,args.baseline)


if __name__=='__main__':main()
