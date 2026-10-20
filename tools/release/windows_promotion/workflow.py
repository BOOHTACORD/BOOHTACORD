"""No auto-merge, mixed write scopes, skipped CI or production writer readback."""
from tools.ci.runner_pool.routing import LINUX
from .intent import require

PERMISSIONS={'push-candidate':{'contents':'write','pull-requests':'read'},
             'candidate-ci':{'contents':'read','actions':'write'},
             'prepare-catalog-pr':{'contents':'read','actions':'read','pull-requests':'write'}}


def validate(documents):
    try:
        workflow=documents['promote-windows-client-update.yaml'];jobs=workflow['jobs']
        require(set(jobs)==set(PERMISSIONS) and workflow['concurrency']=={'group':'windows-client-update-promotion','cancel-in-progress':'false'})
        for name,permissions in PERMISSIONS.items():
            job=jobs[name];require(job['permissions']==permissions and job['environment']=='production' and job['runs-on']==LINUX)
            require(not job.get('continue-on-error'))
            for step in job['steps']:
                require(not step.get('continue-on-error') and 'gh pr merge' not in step.get('run','') and '--auto' not in step.get('run',''))
        require(jobs['candidate-ci']['needs']=='push-candidate' and set(jobs['prepare-catalog-pr']['needs'])=={'push-candidate','candidate-ci'})
        for role,text in [('push-candidate','python -m tools.release.windows_promotion.prepare'),
                           ('prepare-catalog-pr','python -m tools.release.windows_promotion.review')]:
            checks=[s for s in jobs[role]['steps'] if s.get('run')==text]
            require(len(checks)==1 and not checks[0].get('if'))
        checks=[s for s in jobs['candidate-ci']['steps'] if 'tools.release.client_updates.candidate_ci' in s.get('run','')]
        require(len(checks)==1 and not checks[0].get('if') and '--fresh --report .out/windows-promotion/ci.json' in checks[0]['run'])
        checks=[s for s in documents['ci-contracts.yaml']['jobs']['contracts']['steps']
                if s.get('run')=='python3 -m tools.release.windows_promotion.check_source']
        require(len(checks)==1 and not checks[0].get('if'))
        readback=documents['windows-promotion-readback.yaml']
        require(readback['on']['workflow_run']=={'workflows':['Deploy production'],'branches':['master'],'types':['completed']}
                and readback['permissions']=={'contents':'read','actions':'read','pull-requests':'read'})
        job=readback['jobs']['readback']
        require(job['runs-on']==LINUX and not job.get('environment') and not job.get('concurrency')
                and not job.get('secrets') and not job.get('continue-on-error'))
        commands=[s for s in job['steps'] if 'run' in s]
        require([s['run'] for s in commands]==['python -m tools.ci.toolchains.runtime python','python -m tools.release.windows_promotion.readback']
                and all(not s.get('if') and not s.get('continue-on-error') for s in commands))
        require(any(s.get('if')=='always()' and s.get('with',{}).get('path')=='.out/windows-promotion-readback/trace.json'
            and s['with']['if-no-files-found']=='error' and s['with']['retention-days']=='30' for s in job['steps']))
    except (KeyError,TypeError,AttributeError,IndexError) as error:raise ValueError('Incomplete Windows promotion workflow') from error
