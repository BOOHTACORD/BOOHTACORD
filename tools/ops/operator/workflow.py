"""Manual SSH jobs cannot cross capability, credential, approval or writer-queue boundaries."""
from tools.ci.runner_pool.routing import GITHUB_LINUX
from .policy import OPERATIONS,require

JOBS={'audit':('audit-attachment-volume.yaml','audit'),'sample':('qa08-active-upload.yaml','sample'),
      'preflight':('qa11-preflight.yaml','inspect'),'probe':('qa11-preflight.yaml','probe'),
      'rollback':('rehearse-compatible-rollback.yaml','rehearse')}
MASTER="github.repository == 'Egkurilov/BOOHTACORD' && github.ref == 'refs/heads/master'"


def validate(workflows):
    for operation,(filename,job_id) in JOBS.items():
        doc=workflows[filename];job=doc['jobs'][job_id];_,environment,risk,_,_=OPERATIONS[operation]
        require(set(doc['on'])=={'workflow_dispatch'} and doc['permissions']=={'contents':'read','actions':'read'})
        require(doc['on']['workflow_dispatch']['inputs']['dry_run']=={
            'description':'Validate the plan and emit NOT_RUN without host access','type':'boolean','default':'true'})
        require(job.get('environment')==environment and job.get('runs-on')==GITHUB_LINUX
                and job.get('if')==MASTER+(' && inputs.run_probe' if operation=='probe' else ''))
        require(job.get('env',{}).get('SSH_USER')==('shaneque' if risk=='mutation' else 'boohtacord-diag'))
        require(job.get('timeout-minutes')==str(20 if operation=='rollback' else 15 if operation=='probe' else 5))
        require(not any('secrets' in str(value) for value in job.get('env',{}).values()))
        lock=doc.get('concurrency') if operation=='rollback' else job.get('concurrency')
        require(lock=={'group':'v-bootybay-production' if risk=='mutation' else 'v-bootybay-operator-diagnostics','cancel-in-progress':'false'})
        commands=[s.get('run') for s in job['steps'] if 'run' in s]
        require(commands==['python -m tools.ci.toolchains.runtime python','python -m tools.ops.operator.run '+operation])
        invoke=next(s for s in job['steps'] if s.get('run')==commands[-1])
        require(not invoke.get('if') and not invoke.get('continue-on-error'))
        key='DEPLOY_SSH_PRIVATE_KEY' if risk=='mutation' else 'OPERATOR_DIAGNOSTIC_SSH_KEY'
        require(invoke.get('env')=={'GITHUB_TOKEN':'${{ github.token }}','OPERATOR_SSH_PRIVATE_KEY':'${{ secrets.'+key+' }}'})
        uploads=[s for s in job['steps'] if s.get('uses','').startswith('actions/upload-artifact@')]
        require(len(uploads)==1 and uploads[0].get('if')=='always()')
        require(uploads[0]['with']==dict(name='operator-'+operation+'-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',
                path='.out/operator/'+operation+'/receipt.json',**{'if-no-files-found':'error','retention-days':'30'}))
    for filename in set(name for name,_ in JOBS.values()):
        require(set(workflows[filename]['jobs'])=={job for name,job in JOBS.values() if name==filename})
