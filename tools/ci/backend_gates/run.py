"""Execute complete isolated profiles, retaining only public bounded metadata."""
import argparse
import json
import os
import subprocess
import sys
import time
from tools.ci.native import backend
from tools.ci.native.process import ROOT, output, require_version, run
from .results import PROFILES, OPERATIONS, execution, require


def checked_source():
    source=output('git','rev-parse','HEAD')
    require(os.environ.get('GITHUB_SHA',source) == source)
    # Local dirty runs remain useful but cannot produce source-bound PASS.
    subprocess.run(['git','diff','--exit-code','HEAD','--'],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    return source


def load_smoke():
    run(sys.executable,'-m','unittest','tools.load.screen_share_matrix.test_planner')
    for name,accounts,seconds in (('normal',2,20),('reconnect',2,20),('uploads',2,20),('nat_auth',1,20),('faults',2,40)):
        command=[sys.executable,'-m','tools.load.controller.run','--accounts',str(accounts),
                 '--seconds',str(seconds),'--profile',name]
        if name == 'uploads': command += ['--upload-bytes','1024']
        run(*command)


def execute(profile=None):
    names=(profile,) if profile else PROFILES
    directory=ROOT/'.out/ci/backend-parts'; directory.mkdir(parents=True,exist_ok=True)
    # Invalidate old successes before any setup/preflight can fail.
    for name in names:
        (directory/(name+'.json')).write_text(json.dumps({'profile':name,'status':'FAIL'})+'\n')
    source=checked_source()
    require_version('go',output('go','version',cwd=ROOT/'backend').split()[2].removeprefix('go'))
    for name in names:
        row={'source_revision':source,'profile':name,'status':'FAIL','execution':execution()}
        started=time.monotonic()
        try:
            if name == 'load': load_smoke()
            else: backend.run_profile(name)
            require(checked_source() == source)
            row.update(status='PASS',operations=list(OPERATIONS[name]),seconds=time.monotonic()-started)
        finally:
            (directory/(name+'.json')).write_text(json.dumps(row,sort_keys=True)+'\n')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--profile',choices=PROFILES)
    execute(parser.parse_args().profile)


if __name__ == '__main__': main()
