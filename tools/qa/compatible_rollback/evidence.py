"""Reject incomplete rollback evidence; no secret-bearing observation fields."""
import re


PHASES = ('baseline', 'rollback_maintenance', 'previous', 'restore_maintenance', 'restored')
STABLE = ('baseline', 'previous', 'restored')


def require(value):
    if not value:
        raise ValueError('Incomplete or inconsistent real rollback evidence')


def digest(value, size=64):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{%d}' % size, value) is not None


def validate(value):
    try:
        _validate(value)
    except (KeyError, TypeError, AttributeError, IndexError) as error:
        raise ValueError('Incomplete real rollback evidence') from error


def _validate(value):
    require(set(value) == {'status', 'current', 'previous', 'preflight', 'observations', 'storage', 'running', 'observer_seconds'})
    require(value['status'] == 'PASS' and digest(value['current'], 40) and digest(value['previous'], 40)
            and value['current'] != value['previous'])
    require(value['preflight'] == dict.fromkeys(('read_only', 'signed_bundles', 'digest_only', 'compatible'), True))
    require(all(flag is True for flag in value['preflight'].values()))
    require(type(value['observer_seconds']) is int and 30 <= value['observer_seconds'] <= 300)
    observations = value['observations']
    require(len(observations) == 10)
    require({(r['phase'], r['browser']) for r in observations} == {(p, b) for p in PHASES for b in range(2)})
    for row in observations:
        require(set(row) == {'phase', 'browser', 'authenticated', 'banner', 'admission', 'login_status', 'revision'})
        maintenance = row['phase'].endswith('_maintenance')
        require(type(row['browser']) is int and row['authenticated'] is True and row['banner'] is maintenance)
        require(row['admission'] == (503 if maintenance else 201))
        require(row['login_status'] == (503 if maintenance else None if row['phase'] == 'previous' else 204))
        revision = value['previous'] if row['phase'] in ('previous', 'restore_maintenance') else value['current']
        require(row['revision'] == revision)
    storage = value['storage']
    require(len(storage) == 3 and {r['phase'] for r in storage} == set(STABLE))
    for row in storage:
        require(set(row) == {'phase', 'volumes', 'networks', 'content'})
        for key, expected in [('volumes', {'postgres-data', 'attachments-data', 'caddy-data', 'caddy-config'}),
                              ('networks', {'edge', 'private', 'sfu-egress'}),
                              ('content', {'database', 'attachments', 'tls', 'proxy_config', 'schema'})]:
            require(set(row[key]) == expected and all(digest(v) for v in row[key].values()))
            require(row[key] == storage[0][key])
    require(len(value['running']) == 3 and {r['phase'] for r in value['running']} == set(STABLE))
    for row in value['running']:
        require(set(row) == {'phase', 'revision', 'images'})
        require(row['revision'] == value['previous' if row['phase'] == 'previous' else 'current'])
        require(set(row['images']) == {'api', 'web'})
        for service, image in row['images'].items():
            require(set(image) == {'configured', 'running'})
            require(isinstance(image['running'], str) and image['running'].startswith('sha256:') and digest(image['running'][7:]))
            require(image['configured'] == 'voice-platform-' + service + '@' + image['running'])
