"""Prepare or reuse one exact candidate branch, without changing master."""
import json
import os
from pathlib import Path
import re
import subprocess
from tools.ci.native.process import ROOT
from tools.release.client_updates.promote_windows_release import promote
from . import intent

OUT=ROOT/'.out/windows-promotion'


def command(*args,input=None):
    result=subprocess.run(list(args),cwd=ROOT,input=input,text=True,capture_output=True,timeout=60)
    intent.require(result.returncode==0 and len(result.stdout)<=2_000_000)
    return result.stdout.strip()


def git_bytes(*args):return subprocess.check_output(['git',*args],cwd=ROOT,timeout=30)


def outputs(**values):
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf-8') as stream:
            for key,value in values.items():
                intent.require(isinstance(value,str) and '\n' not in value and '\r' not in value)
                stream.write(key+'='+value+'\n')


def open_reviews(expected_branch):
    rows=json.loads(command('gh','pr','list','--repo',intent.REPOSITORY,'--base','master','--state','open',
        '--limit','100','--json','number,headRefName,headRefOid,url'))
    intent.require(isinstance(rows,list) and len(rows)<100)
    promotions=[row for row in rows if row.get('headRefName','').startswith('codex/windows-catalog-')]
    intent.require(all(row['headRefName']==expected_branch for row in promotions) and len(promotions)<=1)
    return promotions


def verify_branch(record,sha):
    intent.require(re.fullmatch('[0-9a-f]{40}',sha))
    parents=command('git','rev-list','--parents','-n','1',sha).split()
    path=intent.DIRECTORY+intent.identifier(record)+'.json'
    intent.require(parents==[sha,record['base_revision']] and set(command('git','diff','--name-only',record['base_revision'],sha).splitlines())=={intent.PATH,path})
    before=git_bytes('show',record['base_revision']+':'+intent.PATH)
    after=git_bytes('show',sha+':'+intent.PATH)
    intent.require(git_bytes('show',sha+':'+path)==intent.raw(record))
    intent.validate(record,before,after)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    tag=os.environ['RELEASE_TAG'];revision=int(os.environ['EXPECTED_REVISION'])
    intent.require(re.fullmatch(r'windows-v\d+\.\d+\.\d+',tag) and os.environ.get('GITHUB_REPOSITORY')==intent.REPOSITORY
                   and os.environ.get('GITHUB_REF')=='refs/heads/master')
    base=command('git','rev-parse','HEAD');intent.require(base==os.environ['GITHUB_SHA'])
    source=ROOT/intent.PATH;before=source.read_bytes()
    metadata=Path(os.environ['RUNNER_TEMP'])/'windows-release'
    release=json.loads((metadata/'release.json').read_text());intent.require(release.get('tag_name')==tag)
    archive=metadata/f'BOOHTACORD-{tag}-x64.zip';manifest=metadata/'artifact-manifest.json';sums=metadata/'SHA256SUMS'
    target=promote(source,revision,release,archive,manifest,sums,intent.REPOSITORY)
    after=source.read_bytes()
    if target['catalog_revision']==revision:
        (OUT/'trace.json').write_text(json.dumps({'status':'NO_CHANGE','source_revision':base,'catalog_revision':revision,
            'physical_acceptance':'NOT_RUN','issue_249':'https://github.com/BOOHTACORD/BOOHTACORD/issues/249'})+'\n')
        outputs(changed='false');return
    observed=json.loads(manifest.read_text())
    from .api import GitHub
    from .release_proof import fingerprint,tag_source
    intent.require(tag_source(GitHub(),tag)==observed.get('source_revision'))
    record=intent.create(before,after,base,{'tag':tag,'source_revision':observed.get('source_revision'),
        'manifest_sha256':intent.digest(manifest.read_bytes()),'archive_sha256':intent.digest(archive.read_bytes()),
        'checksums_sha256':intent.digest(sums.read_bytes()),'asset_inventory_sha256':fingerprint(release)})
    branch=intent.branch(record);open_reviews(branch)
    path=intent.DIRECTORY+intent.identifier(record)+'.json'
    destination=ROOT/path;destination.parent.mkdir(parents=True,exist_ok=True)
    intent.require(not destination.exists());destination.write_bytes(intent.raw(record))
    existing=command('git','ls-remote','origin','refs/heads/'+branch)
    if existing:
        sha=existing.split()[0];command('git','fetch','--no-tags','origin','refs/heads/'+branch);verify_branch(record,sha)
    else:
        command('git','switch','-c',branch)
        intent.require(set(command('git','diff','--name-only').splitlines())=={intent.PATH})
        print(command('git','status','--short'))
        print('Promotion file bytes:',source.stat().st_size,destination.stat().st_size)
        command('git','config','user.name','github-actions[bot]');command('git','config','user.email','41898282+github-actions[bot]@users.noreply.github.com')
        command('git','add','--',intent.PATH,path)
        command('git','commit','-m','chore(updates): prepare '+tag+' catalog promotion')
        sha=command('git','rev-parse','HEAD');verify_branch(record,sha)
        command('git','push','origin','HEAD:refs/heads/'+branch)
    for name,value in [('before.json',before),('after.json',after),('intent.json',intent.raw(record))]:(OUT/name).write_bytes(value)
    (OUT/'trace.json').write_text(json.dumps({'schema_version':1,'status':'NOT_RUN','intent_id':intent.identifier(record),
        'source_revision':base,'candidate_sha':sha,'branch':branch,'candidate_ci':'NOT_RUN','review_pr':'NOT_RUN',
        'merge':'NOT_RUN','deploy':'NOT_RUN','endpoint':'NOT_RUN','physical_acceptance':'NOT_RUN'})+'\n')
    outputs(changed='true',candidate_sha=sha,branch=branch,intent_id=intent.identifier(record))


if __name__=='__main__':main()
