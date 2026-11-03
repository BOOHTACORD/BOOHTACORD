"""Source -> candidate CI -> reviewed PR -> merge -> deployment -> public catalog trace."""
import json
import os
import re
import subprocess
import time
from tools.ci.native.process import ROOT
from . import intent, deployment, endpoint
from .api import GitHub
from .ci_proof import validate
from .prepare import git_bytes
from .review import MARKER
from .noop_readback.verify import probe


def main():
    output=ROOT/'.out/windows-promotion-readback/trace.json';output.parent.mkdir(parents=True,exist_ok=True)
    trace={'schema_version':1,'scope':'source-pr-ci-merge-deploy-catalog','status':'FAIL',
        **{key:{'status':'NOT_RUN'} for key in ('source','release','candidate_ci','review_pr','merge','deployment','endpoint')},
        'physical_acceptance':'NOT_RUN','human_review':'NOT_ASSERTED','issue_249':'https://github.com/BOOHTACORD/BOOHTACORD/issues/249'}
    stage='deployment'
    try:
        value=os.environ['DEPLOY_RUN_ID'];intent.require(re.fullmatch('[1-9][0-9]{0,19}',value))
        api=GitHub();run=api.read('/actions/runs/'+value);intent.require(run['id']==int(value))
        jobs=api.jobs(run['id']);noop=probe(api,run,jobs)
        if noop is not None:
            trace.update(status='NOT_RUN',reason=noop['reason'],deployment=noop);return
        stage='deployment'
        receipt=deployment.receipt(api,run);producer=api.read(f'/actions/runs/{receipt["producer"]["run_id"]}')
        trace['deployment']=deployment.proof(run,jobs,receipt,producer)
        source=trace['deployment']['source_revision']
        stage='source'
        catalog_raw=git_bytes('show',source+':'+intent.PATH);intent.require(len(catalog_raw)<=262144);catalog=json.loads(catalog_raw)
        current_target=intent.digest(intent.raw(intent.entry(catalog)['target']))
        paths=git_bytes('ls-tree','-r','--name-only',source,'--',intent.DIRECTORY).decode().splitlines()
        intent.require(len(paths)<=512)
        candidates=[]
        for path in paths:
            raw=git_bytes('show',source+':'+path);intent.require(len(raw)<=16384)
            record=json.loads(raw)
            if record.get('target_sha256')==current_target and type(record.get('catalog_revision')) is int and record['catalog_revision']<=catalog['catalog_revision']:
                candidates.append((path,record))
        if not candidates:
            trace.update(status='NOT_RUN',reason='no_matching_windows_promotion_intent');return
        latest=max(row[1]['catalog_revision'] for row in candidates)
        candidates=[row for row in candidates if row[1]['catalog_revision']==latest]
        intent.require(len(candidates)==1);path,record=candidates[0]
        intent.require(path==intent.DIRECTORY+intent.identifier(record)+'.json')
        intent.require(re.fullmatch('[0-9a-f]{40}',record.get('base_revision','')))
        before=git_bytes('show',record['base_revision']+':'+intent.PATH)
        introduced=git_bytes('log','-1','--format=%H',source,'--',path).decode().strip()
        subprocess.run(['git','merge-base','--is-ancestor',introduced,source],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
        intent.validate(record,before,git_bytes('show',introduced+':'+intent.PATH))
        trace['source']={'status':'PASS','source_revision':source,'catalog_sha256':intent.digest(catalog_raw),
            'url':f'https://github.com/{intent.REPOSITORY}/commit/{source}'}
        stage='review_pr'
        prs=api.read('/commits/'+introduced+'/pulls')
        merged=[pr for pr in prs if pr.get('merge_commit_sha')==introduced]
        intent.require(len(merged)==1);pr=api.read(f'/pulls/{merged[0]["number"]}')
        intent.require(pr.get('merged') is True and pr['merge_commit_sha']==introduced and pr['base']['ref']=='master'
            and pr['head']['repo']['full_name']==intent.REPOSITORY and pr['head']['ref']==intent.branch(record))
        markers=re.findall(re.escape(MARKER)+r'(.+?) -->',pr.get('body') or '')
        intent.require(len(markers)==1);metadata=json.loads(markers[0])
        intent.require(metadata['intent_id']==intent.identifier(record) and metadata['candidate_sha']==pr['head']['sha'])
        stage='candidate_ci'
        ci=api.read(f'/actions/runs/{metadata["ci_run_id"]}')
        trace['candidate_ci']=validate(ci,api.jobs(ci['id']),pr['head']['ref'],pr['head']['sha'],metadata['ci_run_id'],metadata['ci_run_attempt'])
        trace.update(intent_id=intent.identifier(record),catalog_revision=catalog['catalog_revision'],promotion_catalog_revision=record['catalog_revision'],release=record['release'],
            review_pr={'status':'PASS','url':pr['html_url'],'candidate_sha':pr['head']['sha']},
            merge={'status':'PASS','source_revision':introduced,'url':f'https://github.com/{intent.REPOSITORY}/commit/{introduced}'})
        stage='release'
        from .release_proof import verify
        verify(record,api)
        trace['release']={'status':'PASS',**record['release']}
        stage='endpoint'
        for attempt in range(6):
            try:trace['endpoint']=endpoint.observe(catalog);break
            except Exception:
                if attempt==5:raise ValueError('Intended public catalog was not observed') from None
                time.sleep(10)
        current=api.read('/actions/runs/'+value)
        intent.require(current.get('run_attempt')==run['run_attempt'] and current.get('conclusion')=='success' and current.get('status')=='completed')
        trace['status']='PASS'
    except Exception:
        trace['failure_stage']=stage
        trace[stage]={'status':'FAIL','failure_code':'verification_failed'}
        raise SystemExit('Windows promotion readback verification failed: '+stage) from None
    finally:
        output.write_text(json.dumps(trace,sort_keys=True,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
