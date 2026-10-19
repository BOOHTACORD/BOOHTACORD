"""Preview or validate a local configuration rollback candidate; never push, deploy or alter protection."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from tools.ci.native.process import ROOT
from .readiness import require,git,policy


PREFIXES=('.github/','tools/ci/','tools/verify/workflows/','tools/verify/action_pins/')
EXACT={'tools/verify/github_workflows/verify-github-workflows.ps1','Taskfile.yml','.actionlint.yaml','.node-version','tools/toolchains.json','tools/requirements-ci.txt'}


def eligible(path):
    return (isinstance(path,str) and '..' not in path.split('/') and '\n' not in path and '\\' not in path
            and Path(path).suffix.lower() not in ('.p12','.pem','.key','.mobileprovision','.zip','.apk','.ipa','.dmg')
            and not any(part.startswith('.env') for part in path.split('/')) and (path.startswith(PREFIXES) or path in EXACT))


def require_branch(name):require(re.fullmatch('codex/workflow-rollback-[0-9a-f]{8}',name))


def preview(checkpoint):
    source=git('rev-parse','HEAD');require(checkpoint in policy()['rollback_checkpoints'])
    subprocess.run(['git','merge-base','--is-ancestor',checkpoint,source],cwd=ROOT,check=True)
    subprocess.run(['git','diff','--quiet','HEAD','--'],cwd=ROOT,check=True)
    changed=git('diff','--name-only','--no-renames',checkpoint,source,'--').splitlines()
    paths=[p for p in changed if eligible(p)];require(paths)
    require('name: ci-required' in git('show',checkpoint+':.github/workflows/ci.yaml'))
    patch=subprocess.check_output(['git','diff','--no-renames','--binary',source,checkpoint,'--',*paths],cwd=ROOT)
    directory=ROOT/'.out/ci/migration';directory.mkdir(parents=True,exist_ok=True)
    (directory/'workflow-rollback.patch').write_bytes(patch)
    plan=dict(schema_version=1,source_revision=source,checkpoint=checkpoint,paths=paths,
              preserved=[p for p in changed if p not in paths],patch_sha256=hashlib.sha256(patch).hexdigest(),
              candidate_branch='codex/workflow-rollback-'+source[:8],production_mutation=False)
    (directory/'workflow-rollback.json').write_text(json.dumps(plan,sort_keys=True)+'\n');return plan


def apply(plan):
    require(plan.get('source_revision')==git('rev-parse','HEAD') and plan.get('checkpoint') in policy()['rollback_checkpoints'])
    require_branch(git('branch','--show-current'));require(git('branch','--show-current')==plan['candidate_branch'])
    subprocess.run(['git','diff','--quiet','HEAD','--'],cwd=ROOT,check=True)
    patch=ROOT/'.out/ci/migration/workflow-rollback.patch';raw=patch.read_bytes()
    require(hashlib.sha256(raw).hexdigest()==plan['patch_sha256'] and plan['paths'] and all(eligible(p) for p in plan['paths']))
    expected=subprocess.check_output(['git','diff','--no-renames','--binary',plan['source_revision'],plan['checkpoint'],'--',*plan['paths']],cwd=ROOT)
    require(expected==raw)
    subprocess.run(['git','apply','--index',str(patch)],cwd=ROOT,check=True)
    changed=git('diff','--cached','--no-renames','--name-only').splitlines();require(set(changed)==set(plan['paths']))
    return dict(status='CANDIDATE_CREATED',source_revision=plan['source_revision'],production_mutation=False)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['preview','apply']);parser.add_argument('--checkpoint',default=policy()['rollback_checkpoints'][0]);args=parser.parse_args()
    if args.mode=='preview':result=preview(args.checkpoint)
    else:result=apply(json.loads((ROOT/'.out/ci/migration/workflow-rollback.json').read_text()))
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':main()
