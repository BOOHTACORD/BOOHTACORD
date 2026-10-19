"""Read-only migration readiness: tracked hashed evidence plus authenticated owner review, never a caller GO flag."""
import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from tools.ci.native.process import ROOT
from tools.ops.operator import approval
from tools.ci.artifact_policy.capture_data import safe_json,strict_json

CRITERIA=Path(__file__).with_name('criteria-v1.json')


def require(value):
    if not value:raise ValueError('Migration source, evidence scope, integrity or review is unverified')


def policy():return json.loads(CRITERIA.read_text())
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()


@dataclass(frozen=True)
class VerifiedReceipt:
    criterion:str
    source:str
    scope:str
    sha256:str


@dataclass(frozen=True)
class VerifiedApproval:
    source:str
    reviewer_ids:tuple
    review_run_id:str


def tracked(path):
    require(isinstance(path,str) and re.fullmatch(r'evidence/[A-Za-z0-9_./-]+\.(json|md)',path) and '..' not in path.split('/'))
    entry=git('ls-tree','HEAD','--',path).split('\t')[0].split()
    require(len(entry)==3 and entry[0]=='100644' and entry[1]=='blob')
    raw=subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT,stderr=subprocess.DEVNULL)
    require(0<len(raw)<=2_000_000);return raw


def equivalent_source(source):
    require(re.fullmatch('[0-9a-f]{40}',source))
    subprocess.run(['git','merge-base','--is-ancestor',source,'HEAD'],cwd=ROOT,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    paths=git('diff','--name-only','--no-renames',source,'HEAD','--').splitlines()
    require(all(p.startswith('evidence/') for p in paths))
    subprocess.run(['git','diff','--quiet','HEAD','--'],cwd=ROOT,check=True)


def verify_receipt(path,source):
    raw=tracked(path);row=strict_json(raw);safe_json(row)
    key=row.get('criterion');scope=policy()['criteria'].get(key)
    require(scope and row.get('schema_version')==1 and row.get('status')=='PASS'
            and row.get('source_revision')==source and row.get('scope')==scope and row.get('executed') is True)
    if scope=='actual':require(row.get('actual_runtime') is True and row.get('mocks') is False)
    if scope=='admin':require(row.get('settings_readback_verified') is True and row.get('required_status')=='ci-required')
    references=row.get('evidence');require(isinstance(references,list) and references and len(references)<=100)
    for ref in references:
        require(ref.get('path')!=path and re.fullmatch('[0-9a-f]{64}',ref.get('sha256','')))
        require(hashlib.sha256(tracked(ref['path'])).hexdigest()==ref['sha256'])
    if key in ('baseline','after-observation'):
        require(type(row.get('sample_count')) is int and row['sample_count']>=30)
    if key=='control-matrix':
        cases=row.get('cases',[]);require({c.get('name') for c in cases}=={'docs-only','backend','web','flutter','windows','contracts','shared','unknown'} and len(cases)==8)
        require(all(c.get('status')=='PASS' and c.get('base_revision')==source and c.get('actual_workflow') is True for c in cases))
    required={
        'server-release':('bundle_signature_verified','full_smoke_verified','image_source_verified'),
        'windows-promotion-installed-client':('candidate_reviewed','endpoint_source_verified','old_client_verified'),
        'security-provenance-negatives':('producer_artifact_signature_health_cancel_race_passed',),
        'same-sha-suite-shadows':('same_source_verified','coverage_not_reduced','old_new_equivalent'),
        'trusted-install-readback':('source_readback_verified','health_verified','volume_schema_identity_verified'),
        'schema-compatible-rollback':('compatible_schema_verified','current_restored'),
        'operator-boundaries':('diagnostics_key_restricted','production_lock_verified','independent_review_verified'),
        'macos-sdk-matrix':('both_architectures_verified','native_route_tests_passed'),
    }
    require(all(row.get(flag) is True for flag in required.get(key,())))
    if key in ('android-smoke','windows-smoke','macos-smoke'):require(row.get('native_process_verified') is True)
    if key=='after-observation':
        metrics=row.get('metrics',{})
        require(all(isinstance(metrics.get(name),dict) and type(metrics[name].get('n')) is int and metrics[name]['n']>0
                    and all(type(metrics[name].get(p)) in (int,float) and metrics[name][p]>=0 for p in ('p50','p95'))
                    for name in ('pr_to_green','master_to_healthy','runner_execution_minutes')))
    if key=='workflow-configuration-rollback':require(row.get('candidate_checked') is True and row.get('production_mutation') is False)
    return VerifiedReceipt(key,source,scope,hashlib.sha256(raw).hexdigest())


def evaluate(source,records,owner):
    require(re.fullmatch('[0-9a-f]{40}',source));outstanding=[];accepted=[]
    for key,scope in policy()['criteria'].items():
        row=records.get(key)
        if isinstance(row,VerifiedReceipt) and (row.criterion,row.source,row.scope)==(key,source,scope):accepted.append(key)
        else:outstanding.append(key)
    approved=isinstance(owner,VerifiedApproval) and owner.source==source and bool(owner.reviewer_ids)
    if not approved:outstanding.append('authenticated-owner-GO')
    return dict(schema_version=1,scope='migration-readiness',source_revision=source,
                decision='GO' if not outstanding else 'NO-GO',accepted=accepted,outstanding=outstanding,
                production_mutation=False,repository_settings_changed=False,owner_review_verified=approved)


def owner_review(source):
    env=os.environ;require(env.get('GITHUB_REF')=='refs/heads/master' and env.get('GITHUB_EVENT_NAME')=='workflow_dispatch'
        and env.get('REQUEST_GO_REVIEW')=='true' and git('rev-parse','HEAD')==env.get('GITHUB_SHA'))
    plan=dict(run_id=env['GITHUB_RUN_ID'],source_revision=env['GITHUB_SHA'],actor_id=int(env['GITHUB_ACTOR_ID']),
              workflow='ci-cutover-review.yaml',environment='production',risk='mutation')
    return VerifiedApproval(source,tuple(approval.verify(plan)),env['GITHUB_RUN_ID'])


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--source');parser.add_argument('--manifest',default='evidence/ci/cutover-acceptance-template.json')
    parser.add_argument('--review',action='store_true');parser.add_argument('--prepare-review',action='store_true');args=parser.parse_args();source=args.source or git('rev-parse','HEAD')
    records={};errors=[];owner=None
    try:
        equivalent_source(source);manifest=strict_json(tracked(args.manifest))
        require(manifest.get('schema_version')==1 and isinstance(manifest.get('records'),list) and len(manifest['records'])<=30)
        for path in manifest['records']:
            try:
                record=verify_receipt(path,source);require(record.criterion not in records);records[record.criterion]=record
            except Exception:errors.append('UnverifiedReceipt')
        if args.review and len(records)==len(policy()['criteria']) and not errors:owner=owner_review(source)
    except Exception as error:errors.append(type(error).__name__)
    report=evaluate(source,records,owner);report['verification_errors']=errors
    ready=not errors and len(report['accepted'])==len(policy()['criteria'])
    report['ready_for_owner_review']=ready
    if os.environ.get('GITHUB_OUTPUT'):
        with Path(os.environ['GITHUB_OUTPUT']).open('a') as stream:stream.write('ready_for_review='+str(ready).lower()+'\n')
    if errors:report['decision']='NO-GO'
    destination=ROOT/'.out/ci/migration';destination.mkdir(parents=True,exist_ok=True)
    (destination/'readiness.json').write_text(json.dumps(report,sort_keys=True)+'\n')
    text='## Migration '+report['decision']+'\n\nSource: `'+source+'`\n\nOutstanding: '+', '.join(report['outstanding'])+'\n'
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a') as stream:stream.write(text)
    print('Migration '+report['decision']+'; accepted '+str(len(report['accepted']))+'/'+str(len(policy()['criteria']))+'; no mutation performed')
    return 0 if report['decision']=='GO' or args.prepare_review and ready else 1


if __name__=='__main__':raise SystemExit(main())
