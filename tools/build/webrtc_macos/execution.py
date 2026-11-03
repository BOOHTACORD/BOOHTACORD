"""Only fresh disposable hosted dispatches qualify as publishable SDK candidates."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from tools.ci.native.process import ROOT
from .contract import require


def context():
    source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    require(os.environ.get('GITHUB_ACTIONS')=='true' and os.environ.get('RUNNER_ENVIRONMENT')=='github-hosted'
            and os.environ.get('GITHUB_REPOSITORY')=='BOOHTACORD/BOOHTACORD'
            and os.environ.get('GITHUB_EVENT_NAME')=='workflow_dispatch' and os.environ.get('GITHUB_SHA')==source)
    run=os.environ.get('GITHUB_RUN_ID','');attempt=os.environ.get('GITHUB_RUN_ATTEMPT','')
    require(re.fullmatch('[0-9a-f]{40}',source) and re.fullmatch('[1-9][0-9]*',run) and re.fullmatch('[1-9][0-9]*',attempt))
    subprocess.run(['git','diff','--quiet','HEAD','--'],cwd=ROOT,check=True)
    return dict(builder_revision=source,run_id=run,run_attempt=attempt)


def own(workspace,arch):
    identity=context();base=ROOT/'.out/webrtc'
    require(workspace==base/'sdk' and not base.exists())
    base.mkdir(parents=True,mode=0o700)
    (base/'owner.json').write_text(json.dumps(dict(identity,architecture=arch))+'\n')
    workspace.mkdir();return identity


def cleanup(arch):
    identity=context();base=ROOT/'.out/webrtc'
    if not base.exists():return
    require(not base.is_symlink() and base.resolve()==base)
    marker=base/'owner.json';require(marker.is_file() and not marker.is_symlink() and marker.stat().st_size<=1024)
    require(json.loads(marker.read_text())==dict(identity,architecture=arch))
    shutil.rmtree(base);require(not base.exists())
    receipt=ROOT/'.out/sdk-assets'/('sdk-'+arch+'.json')
    if receipt.is_file():
        require(not receipt.is_symlink() and receipt.stat().st_size<=2_000_000)
        row=json.loads(receipt.read_text());require(all(row.get(k)==v for k,v in identity.items()))
        row['owned_workspace_removed']=True;receipt.write_text(json.dumps(row,sort_keys=True)+'\n')


def main():
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--arch',choices=['arm64','x64'],required=True);args=parser.parse_args()
    cleanup(args.arch)


if __name__=='__main__':main()
