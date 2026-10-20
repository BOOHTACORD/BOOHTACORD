"""Manual quality-only experiment; never another publisher or master producer."""
from .results import require

MASTER="github.repository == 'Egkurilov/BOOHTACORD' && github.ref == 'refs/heads/master'"
POSTGRES='postgres://voice_platform_test:test-only-password@127.0.0.1:5432/voice_platform_test?sslmode=disable'
SUFFIX='${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
VERIFY_PYTHON='python -m tools.ci.toolchains.runtime python'
LEGACY='python3 -m tools.ci.backend_gates.shadow_legacy'
MEASURE='python3 -m tools.ci.backend_gates.shadow_measure'


def step_kind(step):
    if step.get('run'):return step['run']
    return step['uses'].split('@',1)[0]


def validate(document):
    try:
        require(set(document['on'])=={'workflow_dispatch'}
                and document['permissions']=={'contents':'read','actions':'read'}
                and document['concurrency']=={'group':'backend-shadow-${{ github.ref }}','cancel-in-progress':'true'})
        jobs=document['jobs'];require(set(jobs)=={'legacy','profiles','compare'})
        require(jobs['profiles']=={'if':MASTER,'uses':'./.github/workflows/ci-backend.yaml',
                                   'with':{'release_receipt':'false'}})
        old,new=jobs['legacy'],jobs['compare']
        require(old['if']==MASTER and old['runs-on']=='ubuntu-24.04' and old['timeout-minutes']=='30'
                and new['if']=='always() && '+MASTER and new['runs-on']=='ubuntu-24.04'
                and new['needs']==['legacy','profiles'] and new['timeout-minutes']=='10')
        require(old['services']['postgres']['image']=='postgres:17.6-alpine'
                and old['services']['postgres']['ports']==['5432:5432']
                and old['services']['postgres']['env']=={'POSTGRES_DB':'voice_platform_test',
                    'POSTGRES_USER':'voice_platform_test','POSTGRES_PASSWORD':'test-only-password'}
                and old['env']=={'VOICE_PLATFORM_TEST_DATABASE_URL':POSTGRES,'TEST_DATABASE_URL':POSTGRES})
        for job in (old,new):
            require(not any(job.get(k) for k in ('continue-on-error','environment','permissions','strategy','secrets')))
            for step in job['steps']:
                require(not step.get('continue-on-error'))
                if not step.get('uses','').startswith('actions/upload-artifact@'):
                    require(not step.get('if'))
            checkout=[s for s in job['steps'] if s.get('uses','').startswith('actions/checkout@')]
            require(len(checkout)==1 and checkout[0]['with']=={'persist-credentials':'false'})
        require([step_kind(s) for s in old['steps']]==[
                    'actions/checkout','actions/setup-python',VERIFY_PYTHON,
                    'python3 -m tools.ci.toolchains.cache_inputs go','actions/setup-go',LEGACY,'actions/upload-artifact']
                and [step_kind(s) for s in new['steps']]==[
                    'actions/checkout','actions/setup-python',VERIFY_PYTHON,MEASURE+' --prepare-only',
                    'actions/download-artifact','actions/download-artifact','actions/download-artifact',
                    MEASURE,'actions/upload-artifact'])
        downloads=[s['with'] for s in new['steps'] if s.get('uses','').startswith('actions/download-artifact@')]
        require(downloads==[
            {'name':'backend-shadow-legacy-'+SUFFIX,'path':'.out/ci/backend-shadow-inputs/legacy'},
            {'pattern':'backend-part-'+SUFFIX+'-*','path':'.out/ci/backend-shadow-inputs/parts','merge-multiple':'true'},
            {'name':'backend-fan-in-'+SUFFIX,'path':'.out/ci/backend-shadow-inputs/fan-in'}])
        measured=next(s for s in new['steps'] if s.get('run')=='python3 -m tools.ci.backend_gates.shadow_measure')
        require(measured['env']=={'GITHUB_TOKEN':'${{ github.token }}','BACKEND_SHADOW_NEEDS':'${{ toJSON(needs) }}'})
        for job,name,path in ((old,'backend-shadow-legacy-','.out/ci/backend-shadow-legacy.json'),
                              (new,'backend-shadow-','.out/ci/backend-shadow.json')):
            uploads=[s for s in job['steps'] if s.get('uses','').startswith('actions/upload-artifact@')]
            require(len(uploads)==1 and uploads[0].get('if')=='always()'
                    and uploads[0]['with']=={'name':name+SUFFIX,'path':path,'if-no-files-found':'error','retention-days':'30'})
    except (KeyError,TypeError,AttributeError,IndexError,StopIteration) as error:
        raise ValueError('Incomplete backend functional-shadow workflow') from error
