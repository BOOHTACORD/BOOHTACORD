"""Reuse local-feature ownership and parity rules for the complete candidate diff."""
import json
from pathlib import Path
import subprocess

from tools.qa.local_features.policy import covered_features
from tools.verify.client_parity.policy import validate

REGISTRY = 'tools/qa/local_features/features.json'
CLIENT_ROOTS = ('clients/web/src/', 'clients/flutter/lib/')


def review_changes(paths, previous, current):
    product = [path for path in paths if path.startswith(CLIENT_ROOTS)]
    for feature in covered_features(product, current):
        if current[feature].get('parity_review') == previous.get(feature, {}).get('parity_review'):
            raise ValueError('Record platform regression decision for changed feature: ' + feature)
    return [path for path in product if not covered_features([path], current)]


def check(root, changes):
    paths = changes['paths']
    if REGISTRY not in paths and not any(p.startswith(CLIENT_ROOTS) for p in paths):
        return {'status': 'N/A', 'unknown_paths': [], 'reason': 'No registry or client source changes.'}
    try:
        previous = json.loads(subprocess.check_output(
            ['git', 'show', f"{changes['merge_base']}:{REGISTRY}"], cwd=root, stderr=subprocess.DEVNULL))
        current = json.loads((Path(root) / REGISTRY).read_text(encoding='utf-8'))
        validate(current, root)
        unknown = review_changes(paths, previous, current)
        if REGISTRY in changes['staged']:
            staged = json.loads(subprocess.check_output(['git', 'show', f':{REGISTRY}'], cwd=root,
                                                        stderr=subprocess.DEVNULL))
            validate(staged, root)
            unknown = sorted(set(unknown + review_changes(paths, previous, staged)))
        return {'status': 'BLOCKED' if unknown else 'PASS', 'unknown_paths': unknown,
                'reason': 'Review whether unmapped client paths change behavior.' if unknown else 'Registry and parity decisions validated.'}
    except subprocess.CalledProcessError:
        return {'status': 'BLOCKED', 'unknown_paths': [], 'reason': 'Base or staged registry unavailable; fetch history and inspect the index.'}
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        return {'status': 'FAIL', 'unknown_paths': [], 'reason': str(error)}
