"""Enforce the mandatory Web fan-out and the original trusted receipt identity."""
from tools.ci.runner_pool.routing import GITHUB_LINUX
from .catalog import BROWSER_PROFILES
from tools.ci.artifact_policy.capture_inventory import WEB_ROOTS
from tools.ci.artifact_policy.workflows import capture_job

PREFIX = 'web-part-${{ inputs.evidence_namespace }}-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}-'
RECEIPT = 'python3 -m tools.ci.receipts.run web --parts .out/ci/web-parts'
CAPTURES = {'.out/' + name + '/**' for name in WEB_ROOTS}
SFU_CAPTURES = {'.out/screen-profile-browser-results/**/screen-share-sfu-smoke.json',
                '.out/restricted-networks/*.json'}


def require(value):
    if not value:
        raise ValueError('Web workflow must require complete isolated profiles and exact-source receipts')


def uploads(job):
    return [step for step in job['steps'] if step.get('uses', '').startswith('actions/upload-artifact@')]


def capture_paths(step):
    return {line.strip() for line in step['with']['path'].splitlines() if line.strip()}


def validate(document):
    try:
        jobs = document['jobs']
        require(set(jobs) == {'fast', 'browser', 'sfu', 'frontend'})
        require(document['permissions'] == {'contents': 'read'})
        require(document['env']['WEB_NAMESPACE'] == '${{ inputs.evidence_namespace }}')
        for name in ('fast', 'browser', 'sfu'):
            job = jobs[name]
            require(job.get('if') is None and not job.get('needs') and not job.get('continue-on-error'))
            require(job['runs-on'] == GITHUB_LINUX and job['timeout-minutes'] == ('25' if name == 'browser' else '20'))
            profile = {'fast': 'fast', 'browser': '${{ matrix.profile }}', 'sfu': 'sfu-network'}[name]
            commands = [s for s in job['steps'] if 'tools.ci.web_suites.run' in s.get('run', '')]
            require(len(commands) == 1 and commands[0].get('if') is None
                    and not commands[0].get('continue-on-error'))
            command = commands[0]
            expected = 'python3 -m tools.ci.web_suites.run --profile ' + profile
            if name == 'browser':
                expected = 'python3 -m tools.ci.web_suites.run --profile "$WEB_PROFILE"'
                require(command.get('env') == {'WEB_PROFILE': '${{ matrix.profile }}'})
                require(job['strategy'] == {'fail-fast':'false', 'matrix':{'profile':list(BROWSER_PROFILES)}})
            else:
                require('strategy' not in job)
            require(command['run'] == expected)
            allowed = {'python -m tools.ci.toolchains.runtime python',
                       'python3 -m tools.ci.toolchains.cache_inputs npm', expected}
            if name == 'browser':
                allowed |= {'python3 -m tools.ci.artifact_policy.run ' + operation + ' web "$WEB_PROFILE"'
                            for operation in ('begin', 'finish')}
            require({s['run'] for s in job['steps'] if 'run' in s} == allowed)
            node = [i for i, s in enumerate(job['steps']) if s.get('uses', '').startswith('actions/setup-node@')]
            require(len(node) == 1 and node[0] < job['steps'].index(command))
            mandatory = [s for s in uploads(job) if s['with']['name'] == PREFIX + profile]
            require(len(mandatory) == 1 and mandatory[0].get('if') == 'always()')
            require(mandatory[0]['with']['path'] == '.out/ci/web-parts/' + profile + '.json'
                    and mandatory[0]['with']['if-no-files-found'] == 'error')
        capture_job(jobs['browser'], 'web', '${{ matrix.profile }}',
                    'python3 -m tools.ci.web_suites.run --profile "$WEB_PROFILE"')
        sfu = [s for s in uploads(jobs['sfu']) if s['with']['name'].startswith('web-sfu-')]
        require(len(sfu) == 1 and sfu[0].get('if') == 'always()' and capture_paths(sfu[0]) == SFU_CAPTURES)
        job = jobs['frontend']
        require(job.get('name', 'frontend') == 'frontend' and job.get('if') == 'always()'
                and set(job['needs']) == {'fast', 'browser', 'sfu'} and not job.get('continue-on-error'))
        require(job['runs-on'] == GITHUB_LINUX and job['timeout-minutes'] == '5')
        consumers = [s for s in job['steps'] if s.get('uses', '').startswith('actions/download-artifact@')]
        require(len(consumers) == 1 and consumers[0].get('if') is None
                and consumers[0]['with'] == {'pattern':PREFIX + '*', 'path':'.out/ci/web-parts', 'merge-multiple':'true'})
        checks = [s for s in job['steps'] if 'tools.ci.receipts.run' in s.get('run', '')]
        require(len(checks) == 1 and checks[0].get('if') is None and checks[0]['run'] == RECEIPT
                and checks[0].get('env') == {'WEB_NEEDS':'${{ toJSON(needs) }}'})
        receipts = [s for s in uploads(job) if s['with']['name'] == 'check-web-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}']
        require(len(receipts) == 1 and receipts[0].get('if') == 'inputs.release_receipt'
                and receipts[0]['with']['path'] == '.out/checks/web.json'
                and receipts[0]['with']['if-no-files-found'] == 'error')
    except (KeyError, TypeError, AttributeError, IndexError) as error:
        raise ValueError('Incomplete mandatory Web workflow') from error
