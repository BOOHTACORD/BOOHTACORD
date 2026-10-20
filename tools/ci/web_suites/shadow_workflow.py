"""Bounded manual read-only comparison, with no release receipts or publishers."""
from tools.ci.runner_pool.routing import LINUX


def require(value):
    if not value:raise ValueError('Shadow controls must be finite, same-source and read-only')


def validate(document):
    try:
        require(set(document['on'])=={'workflow_dispatch'})
        require(document['permissions']=={'contents':'read','actions':'read'})
        jobs=document['jobs'];require(set(jobs)=={'legacy','profiles','compare'})
        strategy={'fail-fast':'false','max-parallel':'1','matrix':{'sample':['1','2','3']}}
        for name in ('legacy','profiles'):
            job=jobs[name]
            require(job['name']==name+'-${{ matrix.sample }}' and job['strategy']==strategy
                    and job.get('if') is None and not job.get('continue-on-error')
                    and not job.get('environment') and not job.get('secrets'))
        legacy=jobs['legacy']
        require(legacy['runs-on']==LINUX and legacy['timeout-minutes']=='35'
                and legacy['env']=={'WEB_NAMESPACE':'shadow-old-${{ matrix.sample }}'})
        controls=[s for s in legacy['steps'] if 'tools.ci.web_suites.legacy' in s.get('run','')]
        require(len(controls)==1 and controls[0]['run']=='python3 -m tools.ci.web_suites.legacy'
                and controls[0].get('if') is None)
        checkouts=[s for s in legacy['steps'] if s.get('uses','').startswith('actions/checkout@')]
        require(len(checkouts)==1 and checkouts[0]['with']=={'persist-credentials':'false','fetch-depth':'0'})
        require(jobs['profiles']['uses']=='./.github/workflows/ci-frontend.yaml'
                and jobs['profiles']['with']=={'release_receipt':'false','evidence_namespace':'shadow-new-${{ matrix.sample }}'})
        job=jobs['compare']
        require(job['if']=='always()' and set(job['needs'])=={'legacy','profiles'}
                and job['runs-on']==LINUX and job['timeout-minutes']=='5'
                and job['env']=={'WEB_NAMESPACE':'shadow-compare'} and not job.get('continue-on-error'))
        checks=[s for s in job['steps'] if 'tools.ci.web_suites.measure' in s.get('run','')]
        require(len(checks)==1 and checks[0]['run']=='python3 -m tools.ci.web_suites.measure'
                and checks[0].get('if')=='always()'
                and checks[0]['env']=={'SHADOW_NEEDS':'${{ toJSON(needs) }}','GITHUB_TOKEN':'${{ github.token }}'})
        downloads=[s for s in job['steps'] if s.get('uses','').startswith('actions/download-artifact@')]
        expected={'web-'+kind+'-shadow-'+arm+'-*-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
                  for kind,arm in [('legacy','old'),('fan-in','new')]}
        require(len(downloads)==2 and {s['with']['pattern'] for s in downloads}==expected
                and all(s['with']['path']=='.out/ci/shadow-inputs' and s['with']['merge-multiple']=='false' for s in downloads))
        for name,path in [('legacy','.out/ci/web-legacy.json'),('compare','.out/ci/web-shadow.json')]:
            uploads=[s for s in jobs[name]['steps'] if s.get('uses','').startswith('actions/upload-artifact@')]
            require(len(uploads)==1 and uploads[0].get('if')=='always()'
                    and uploads[0]['with']['path']==path and uploads[0]['with']['if-no-files-found']=='error')
    except (KeyError,TypeError,AttributeError,IndexError) as error:
        raise ValueError('Incomplete shadow workflow') from error
