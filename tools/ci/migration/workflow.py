"""Cutover reporting has no production mutation or repository-admin capability."""
from .readiness import require
from tools.ci.runner_pool.routing import META
from tools.verify.action_pins.trust import MASTER


def validate(workflows):
    doc=workflows['ci-cutover-review.yaml'];require(set(doc['on'])=={'workflow_dispatch'}
        and doc['permissions']=={'contents':'read','actions':'read'} and doc['on']['workflow_dispatch']['inputs']['request_go_review']['default']=='false')
    jobs=doc['jobs'];require(set(jobs)=={'prepare','review'} and not jobs['prepare'].get('environment')
        and jobs['review'].get('if')==MASTER+" && inputs.request_go_review && needs.prepare.outputs.ready == 'true'" and jobs['review'].get('environment')=='production' and jobs['review'].get('needs')=='prepare')
    for job in jobs.values():
        require(job.get('runs-on')==META and not job.get('continue-on-error') and not job.get('concurrency'))
        for step in job['steps']:
            require(not step.get('continue-on-error') and 'secrets.' not in str(step))
            if step.get('uses','').startswith('actions/upload-artifact@'):
                require(step.get('if')=='always()' and step['with']['path']=='.out/ci/migration/readiness.json'
                    and step['with']['if-no-files-found']=='error' and step['with']['retention-days']=='30')
