"""Open a review-only PR after exact candidate CI and a fresh master/catalog guard."""
import base64
import json
import os
import re
from .api import GitHub
from .ci_proof import validate
from . import intent
from .prepare import OUT, command, open_reviews, verify_branch

MARKER='<!-- BOOHTACORD_WINDOWS_PROMOTION '


def main():
    record=json.loads((OUT/'intent.json').read_text());proof=json.loads((OUT/'ci.json').read_text())
    intent.validate(record,(OUT/'before.json').read_bytes(),(OUT/'after.json').read_bytes())
    branch=intent.branch(record);sha=os.environ['CANDIDATE_SHA'];api=GitHub()
    intent.require(proof['source_revision']==sha and proof['branch']==branch)
    validate(api.read(f'/actions/runs/{proof["run_id"]}'),api.jobs(proof['run_id']),branch,sha,proof['run_id'],proof['run_attempt'])
    head=api.read('/git/ref/heads/'+branch)['object']['sha'];intent.require(head==sha)
    master=api.read('/contents/'+intent.PATH+'?ref=master')
    intent.require(master.get('encoding')=='base64' and master.get('size',0)<=262144)
    intent.require(intent.digest(base64.b64decode(master['content'],validate=False))==record['base_catalog_sha256'])
    from .release_proof import verify
    verify(record,api)
    current=api.read(f'/actions/runs/{proof["run_id"]}')
    intent.require(current.get('run_attempt')==proof['run_attempt'] and current.get('conclusion')=='success' and current.get('status')=='completed')
    existing=open_reviews(branch)
    metadata={'intent_id':intent.identifier(record),'candidate_sha':sha,'ci_run_id':proof['run_id'],'ci_run_attempt':proof['run_attempt']}
    if existing:
        intent.require(existing[0]['headRefOid']==sha);url=existing[0]['url']
    else:
        body=OUT/'review-body.md'
        body.write_text('Review Windows/direct/stable/x64 promotion of `'+record['release']['tag']+'`.\n\n'
            +'Expected catalog revision '+str(record['expected_catalog_revision'])+' → '+str(record['catalog_revision'])+'. '
            +'Other selectors are unchanged; release assets and complete manifests/checksums were verified.\n\n'
            +'Fresh full candidate CI passed on exact commit `'+sha+'`: '+proof['url']+'\n\n'
            +'This workflow does not merge. GITHUB_TOKEN-created opened/synchronize/reopened pull_request events can create approval-required PR runs; '
            +'workflow_dispatch candidate evidence may not satisfy required PR checks. A writer must approve those workflow runs when prompted, '
            +'and must verify the current required PR/merge checks before merging. '
            +'Automatic source-bound read-only catalog readback follows a successful deploy. '
            +'Production rollout and installed-old-client acceptance remain operator-controlled in #249; physical acceptance is NOT_RUN.\n\n'
            +MARKER+json.dumps(metadata,sort_keys=True)+' -->\n',encoding='utf-8')
        url=command('gh','pr','create','--repo',intent.REPOSITORY,'--base','master','--head',branch,
            '--title','Review Windows update promotion: '+record['release']['tag'],'--body-file',str(body))
    match=re.fullmatch('https://github.com/'+re.escape(intent.REPOSITORY)+r'/pull/([1-9][0-9]*)',url);intent.require(match)
    pr=api.read('/pulls/'+match[1])
    intent.require(pr['state']=='open' and pr['head']['sha']==sha and pr['base']['ref']=='master'
                   and pr['head']['repo']['full_name']==intent.REPOSITORY)
    # Reuse cannot bless a manually changed/foreign PR body.
    markers=re.findall(re.escape(MARKER)+r'(.+?) -->',pr.get('body') or '')
    intent.require(len(markers)==1)
    embedded=json.loads(markers[0])
    intent.require(set(embedded)==set(metadata) and embedded['intent_id']==metadata['intent_id']
        and embedded['candidate_sha']==sha and type(embedded['ci_run_id']) is int and embedded['ci_run_id']>0
        and type(embedded['ci_run_attempt']) is int and embedded['ci_run_attempt']>0)
    original_ci=validate(api.read(f'/actions/runs/{embedded["ci_run_id"]}'),api.jobs(embedded['ci_run_id']),
        branch,sha,embedded['ci_run_id'],embedded['ci_run_attempt'])
    trace=json.loads((OUT/'trace.json').read_text());trace.update(candidate_ci=proof,review_pr={'status':'PASS','url':url,'original_candidate_ci':original_ci},
        status='NOT_RUN',human_review='NOT_ASSERTED')
    (OUT/'trace.json').write_text(json.dumps(trace,sort_keys=True)+'\n',encoding='utf-8')
    print('Prepared review PR: '+url)


if __name__=='__main__':main()
