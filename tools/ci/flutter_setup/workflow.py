"""Bound the local composite to its immutable installer and SDK-only cache."""
import json
from tools.ci.toolchains.spec import public_bytes

MASTER_CACHE_WRITE = "github.repository == 'BOOHTACORD/BOOHTACORD' && github.event_name == 'push' && github.ref == 'refs/heads/master' && inputs.cache == 'true' && steps.sdk-cache.outputs.cache-hit != 'true'"
BINDINGS = {'path': '${{ steps.metadata.outputs.cache_path }}',
            'key': '${{ steps.metadata.outputs.cache_key }}'}


def validate(document, root):
    source = json.loads(public_bytes(root, 'tools/ci/flutter_setup/source.json'))
    pins = json.loads(public_bytes(root, 'tools/verify/action_pins/pins.json'))
    approved = {row['action']: row['commit'] for row in pins['actions']}
    steps = document.get('runs', {}).get('steps', [])
    if len(steps) != 5:
        raise ValueError('Complete reviewed Flutter SDK composite required')
    prepare, checkout, restore, install, save = steps
    expected_checkout = {'repository': source['installer_repository'], 'ref': source['installer_revision'],
                         'path': '.out/ci/flutter-installer', 'persist-credentials': 'false'}
    if (document['runs'].get('using') != 'composite'
            or set(document.get('inputs', {})) != {'flutter-version', 'channel', 'cache'}
            or prepare.get('if') is not None or prepare.get('id') != 'metadata'
            or prepare.get('run') != '"$BOOHTACORD_CI_PYTHON" -m tools.ci.flutter_setup.run prepare'
            or checkout.get('uses') != 'actions/checkout@' + approved['actions/checkout']
            or checkout.get('with') != expected_checkout or checkout.get('if') is not None
            or restore.get('uses') != 'actions/cache/restore@' + approved['actions/cache/restore']
            or restore.get('id') != 'sdk-cache' or restore.get('with') != BINDINGS
            or restore.get('if') != "inputs.cache == 'true'"
            or install.get('if') is not None
            or install.get('run') != '"$BOOHTACORD_CI_PYTHON" -m tools.ci.flutter_setup.run install'
            or save.get('uses') != 'actions/cache/save@' + approved['actions/cache/save']
            or save.get('with') != BINDINGS or save.get('if') != MASTER_CACHE_WRITE):
        raise ValueError('Immutable SDK installer, private pub and read-only PR cache contract required')
