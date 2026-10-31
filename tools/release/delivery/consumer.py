"""Bind installation control code to the protected caller, not a historical bundle."""
import json
import os
import re
from pathlib import Path
from .commands import execute
from .provenance import validate as producer

REPOSITORY = 'BOOHTACORD/BOOHTACORD'
WORKFLOWS = {'automatic': ('workflow_run', 'deploy-production.yaml'),
             'retained': ('workflow_dispatch', 'install-retained-release.yaml')}


def validate(env, event, head):
    mode = env.get('DELIVERY_MODE')
    if (mode not in WORKFLOWS or not isinstance(head, str) or not re.fullmatch('[a-f0-9]{40}', head)
            or env.get('GITHUB_ACTIONS') != 'true' or env.get('RUNNER_OS') != 'Linux'
            or env.get('GITHUB_REPOSITORY') != REPOSITORY or env.get('GITHUB_REF') != 'refs/heads/master'
            or env.get('GITHUB_SHA') != head or not isinstance(event, dict)
            or not isinstance(event.get('repository'), dict)
            or event['repository'].get('full_name') != REPOSITORY):
        raise ValueError('Untrusted delivery controller')
    event_name, workflow = WORKFLOWS[mode]
    if (env.get('GITHUB_EVENT_NAME') != event_name or env.get('GITHUB_WORKFLOW_REF') !=
            f'{REPOSITORY}/.github/workflows/{workflow}@refs/heads/master'):
        raise ValueError('Unexpected delivery caller')
    run_id, requested = env.get('BUILD_RUN_ID', ''), env.get('REQUESTED_REVISION', '')
    if not isinstance(run_id, str) or not re.fullmatch('[1-9][0-9]{0,19}', run_id):
        raise ValueError('Invalid producer run identity')
    if mode == 'automatic':
        run = event.get('workflow_run')
        if not isinstance(run, dict) or type(run.get('id')) is not int or str(run['id']) != run_id or requested:
            raise ValueError('Delivery producer differs from workflow event')
        producer(run, REPOSITORY)
    else:
        inputs = event.get('inputs')
        if (not isinstance(requested, str) or not re.fullmatch('[a-f0-9]{40}', requested)
                or not isinstance(inputs, dict) or inputs.get('build_run_id') != run_id
                or inputs.get('revision') != requested):
            raise ValueError('Retained delivery differs from dispatch inputs')
    return head


def main():
    path = Path(os.environ['GITHUB_EVENT_PATH'])
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 2_097_152:
        raise ValueError('Invalid delivery event file')
    event = json.loads(path.read_bytes())
    head = execute(['git', 'rev-parse', 'HEAD'], 10, capture_limit=128).decode('ascii').strip()
    validate(os.environ, event, head)
    execute(['git', 'diff', '--exit-code', 'HEAD', '--'], 10)
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
        stream.write('controller_revision=' + head + '\n')
    print('Verified protected delivery controller ' + head)


if __name__ == '__main__': main()
