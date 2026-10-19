"""Reviewed Web coverage and immutable reference commands for every profile."""
import hashlib
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(__file__).resolve().parent
BASELINE_SHA256 = '30384e8d783a60707decf85bcaafc5171d882c1829c68deb75e674c9c2a92188'
PROFILES = ('fast', 'browser-shell', 'browser-conversations', 'browser-voice', 'sfu-network')


def require(value):
    if not value:
        raise ValueError('Web suite coverage or reviewed command inventory is incomplete or changed')


def baseline():
    data = (DIRECTORY / 'baseline-v1.json').read_bytes().replace(b'\r\n', b'\n')
    require(hashlib.sha256(data).hexdigest() == BASELINE_SHA256)
    return json.loads(data)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                     allow_nan=False).encode()).hexdigest()


def execution():
    namespace = os.environ.get('WEB_NAMESPACE', 'web')
    require(re.fullmatch('[a-z][a-z0-9-]{0,39}', namespace))
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        run_id = os.environ.get('GITHUB_RUN_ID', '')
        attempt = os.environ.get('GITHUB_RUN_ATTEMPT', '')
        require(re.fullmatch('[1-9][0-9]{0,19}', run_id)
                and re.fullmatch('[1-9][0-9]{0,3}', attempt))
    else:
        run_id, attempt = 'local', '1'
    return {'run_id': run_id, 'run_attempt': attempt, 'namespace': namespace}


def validate(value, scripts):
    try:
        expected = baseline()
        require(set(value) == {'schema_version', 'profiles', 'operations', 'script_inventory'})
        require(value['schema_version'] == 1 and set(value['profiles']) == set(PROFILES))
        required = expected['operations'] | expected['additional_checks']
        require(all(value['operations'].get(name) == operation for name, operation in required.items()))
        relevant = {k: v for k, v in scripts.items()
                    if k.startswith('test') or k in ('build', 'verify:social-preview')}
        require(value['script_inventory'] == relevant)
        for name, operation in value['operations'].items():
            if name not in required:
                require(name.startswith('npm:test:') and name[4:] in relevant
                        and operation == {'command':['npm','run',name[4:]], 'cwd':'web',
                                          'sfu':False, 'smoke_env':False})
        covered = {name[4:] for name in value['operations'] if name.startswith('npm:')}
        require(covered | set(expected['aliases']) == set(relevant)
                and relevant['test:watch'] == 'vitest'
                and relevant['test:audio'] == relevant['test:audio:browser'])
        selected = []
        for name, operations in value['profiles'].items():
            require(isinstance(operations, list) and operations
                    and all(isinstance(item, str) and item in value['operations'] for item in operations))
            selected.extend(operations)
            require(all(not value['operations'][item]['sfu'] or name == 'sfu-network' for item in operations))
        require(len(selected) == len(set(selected)) and set(selected) == set(value['operations']))
        # The actual SFU process must be closed before restricted-network setup.
        sfu = value['profiles']['sfu-network']
        require(sfu == ['npm:test:audio:quality', 'npm:test:screen-profile-sfu',
                        'npm:test:audio:browser', 'python:tools.network.restricted.run'])
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError('Malformed Web suite coverage inventory') from error


def plan():
    value = json.loads((DIRECTORY / 'plan-v1.json').read_text())
    scripts = json.loads((ROOT / 'clients/web/package.json').read_text())['scripts']
    validate(value, scripts)
    return value
