"""Require finite capture publication and unchanged durable native/proof uploads."""
from .retention import CAPTURE_EXPRESSION
from .names import PREFIXES

CONTEXT = '${{ inputs.evidence_namespace }}-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'


def require(value):
    if not value:
        raise ValueError('Artifact policy requires current verified packages and durable mandatory proof')


def uploads(job):
    return [s for s in job['steps'] if s.get('uses', '').startswith('actions/upload-artifact@')]


def capture_job(job, component, profile, test_command):
    argument = '"$WEB_PROFILE"' if component == 'web' else 'dart'
    base = 'python3 -m tools.ci.artifact_policy.run '
    commands = [base + operation + ' ' + component + ' ' + argument for operation in ('begin', 'finish')]
    found = []
    env = {'WEB_PROFILE': profile} if component == 'web' else {'FLUTTER_EVIDENCE_NAMESPACE': '${{ inputs.evidence_namespace }}'}
    for operation, command in zip(('begin', 'finish'), commands):
        steps = [s for s in job['steps'] if s.get('run') == command]
        require(len(steps) == 1)
        step = steps[0]
        require(not step.get('continue-on-error') and step.get('if') == ('always()' if operation == 'finish' else None)
                and step.get('env') == (env if operation == 'begin' else {**env, 'CAPTURE_UPSTREAM_STATUS': '${{ job.status }}'}))
        found.append(job['steps'].index(step))
    tests = [i for i, s in enumerate(job['steps']) if s.get('run') == test_command]
    require(len(tests) == 1 and found[0] < tests[0] < found[1])
    retained = uploads(job)
    path = '.out/ci/capture-packages/' + component + '-' + profile + '/'
    package = [s for s in retained if s.get('with', {}).get('path') == path]
    require(len(package) == 1 and len(retained) == 2)
    item = package[0]
    proof = next(s for s in retained if s is not item)
    require(tests[0] < job['steps'].index(proof) < found[1])
    prefix = 'web-visual-' if component == 'web' else 'uiux-flutter-visual-review-'
    name = prefix + CONTEXT + ('-' + profile if component == 'web' else '')
    require(item.get('if') == 'always()' and not item.get('continue-on-error')
            and item['with'] == {'name': name, 'path': path, 'if-no-files-found': 'error', 'retention-days': CAPTURE_EXPRESSION}
            and found[1] < job['steps'].index(item))


def windows(job):
    suffix = '-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
    retained = uploads(job)
    require(len(retained) == len(PREFIXES)
            and {s['with']['name'] for s in retained} == {name + suffix for name in PREFIXES.values()}
            and all(s['with'].get('retention-days') == '30' for s in retained))
