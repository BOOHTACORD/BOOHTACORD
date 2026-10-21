"""Keep every backend profile mandatory and all PostgreSQL fixtures isolated."""
from tools.ci.runner_pool.routing import GITHUB_LINUX
from .results import PROFILES

EXECUTION='${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
PREFIX='backend-part-'+EXECUTION+'-'
DATABASE='postgres://voice_platform_test:test-only-password@127.0.0.1:5432/voice_platform_test?sslmode=disable'


def require(value):
    if not value:
        raise ValueError('Backend workflow must preserve all mandatory isolated profiles and receipts')


def validate(document):
    try:
        jobs=document['jobs']
        require(set(jobs) == {*PROFILES,'backend'} and document['permissions'] == {'contents':'read'})
        for name in PROFILES:
            job=jobs[name]
            require(job.get('if') is None and not job.get('needs') and not job.get('continue-on-error')
                    and not job.get('strategy') and job['runs-on'] == GITHUB_LINUX)
            require(job['timeout-minutes'] == '20')
            if name == 'database':
                require(job['env'] == {'VOICE_PLATFORM_TEST_DATABASE_URL':DATABASE,'TEST_DATABASE_URL':DATABASE})
                postgres=job['services']['postgres']
                require(set(job['services']) == {'postgres'} and postgres['image'] == 'postgres:17.6-alpine'
                        and postgres['ports'] == ['5432:5432']
                        and postgres['env'] == {'POSTGRES_DB':'voice_platform_test',
                            'POSTGRES_USER':'voice_platform_test','POSTGRES_PASSWORD':'test-only-password'})
            else: require(not job.get('services') and not job.get('env'))
            commands=[s for s in job['steps'] if 'run' in s]
            require([s['run'] for s in commands] == ['python -m tools.ci.toolchains.runtime python',
                'python3 -m tools.ci.toolchains.cache_inputs go',
                'python3 -m tools.ci.backend_gates.run --profile '+name])
            require(all(s.get('if') is None and not s.get('continue-on-error') for s in commands))
            parts=[s for s in job['steps'] if s.get('with',{}).get('name') == PREFIX+name]
            require(len(parts)==1 and parts[0].get('if') == 'always()' and parts[0]['with'] == {
                'name':PREFIX+name,'path':'.out/ci/backend-parts/'+name+'.json',
                'if-no-files-found':'error','retention-days':'30'})
        load=jobs['load']
        evidence=[s for s in load['steps'] if s.get('with',{}).get('name') == 'backend-load-smoke-'+EXECUTION]
        require(len(evidence)==1 and evidence[0].get('if') == 'always()' and evidence[0]['with'] == {
            'name':'backend-load-smoke-'+EXECUTION,'path':'.out/backend-load/**/report.json\n.out/backend-load/**/routes.csv\n.out/backend-load/**/report.html\n',
            'if-no-files-found':'error','retention-days':'14'})
        job=jobs['backend']
        require(job.get('name','backend') == 'backend' and job.get('if') == 'always()'
                and set(job['needs']) == set(PROFILES) and not job.get('continue-on-error'))
        steps=job['steps']
        downloads=[s for s in steps if s.get('uses','').startswith('actions/download-artifact@')]
        require(len(downloads)==1 and downloads[0].get('if') is None and downloads[0]['with'] == {
            'pattern':PREFIX+'*','path':'.out/ci/backend-parts','merge-multiple':'true'})
        receipts=[s for s in steps if 'tools.ci.receipts.run' in s.get('run','')]
        require(len(receipts)==1 and receipts[0].get('if') is None and not receipts[0].get('continue-on-error')
                and receipts[0]['run'] == 'python3 -m tools.ci.receipts.run backend --parts .out/ci/backend-parts'
                and receipts[0].get('env') == {'BACKEND_NEEDS':'${{ toJSON(needs) }}'})
        uploads=[s for s in steps if s.get('with',{}).get('path') == '.out/checks/backend.json']
        require(len(uploads)==1 and uploads[0].get('if') == 'inputs.release_receipt' and uploads[0]['with'] == {
            'name':'check-backend-'+EXECUTION,'path':'.out/checks/backend.json',
            'if-no-files-found':'error','retention-days':'30'})
    except (KeyError,TypeError,AttributeError,IndexError) as error:
        raise ValueError('Incomplete backend workflow') from error
