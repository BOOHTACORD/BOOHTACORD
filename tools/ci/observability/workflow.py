"""Diagnostic failures and retention cannot disappear behind a successful required aggregate."""
from .triage import require


def check_job(job,scope):
    require(job.get('permissions')=={'contents':'read','actions':'read'})
    if scope=='pr':
        checkouts=[s for s in job['steps'] if s.get('uses','').startswith('actions/checkout@')]
        require(len(checkouts)==1 and checkouts[0].get('with',{}).get('fetch-depth')=='2')
    summaries=[s for s in job['steps'] if s.get('run')=='python -m tools.ci.observability.summary --scope '+scope]
    require(len(summaries)==1 and summaries[0].get('if')=='always()' and not summaries[0].get('continue-on-error'))
    require(summaries[0].get('env')=={'GITHUB_TOKEN':'${{ github.token }}','TRIAGE_NEEDS':'${{ toJSON(needs) }}','CI_GATE_OUTCOME':'${{ job.status }}'})
    uploads=[s for s in job['steps'] if s.get('with',{}).get('path')=='.out/ci/triage/'+scope+'.json']
    require(len(uploads)==1 and uploads[0].get('if')=='always()' and not uploads[0].get('continue-on-error'))
    require(uploads[0]['with']=={'name':'triage-'+scope+'-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',
        'path':'.out/ci/triage/'+scope+'.json','if-no-files-found':'error','retention-days':'30'})


def validate(workflows):
    for file,job,scope in [('ci.yaml','ci-required','pr'),('build-server.yaml','server-quality','server'),('native-master.yaml','native-required','native')]:
        check_job(workflows[file]['jobs'][job],scope)
    manual=workflows['ci-observability.yaml'];require(set(manual['on'])=={'workflow_dispatch'}
        and manual['permissions']=={'contents':'read','actions':'read'} and all(not j.get('environment') for j in manual['jobs'].values()))
