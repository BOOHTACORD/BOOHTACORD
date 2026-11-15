"""Detect changes to npm dependency declarations, not unrelated metadata."""
import json
import subprocess


def web_dependency_change(before, after):
    old, new = json.loads(before), json.loads(after)
    if not isinstance(old, dict) or not isinstance(new, dict):
        raise ValueError('Manifest must be an object')
    keys = ('dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies', 'overrides')
    return any(old.get(key, {}) != new.get(key, {}) for key in keys)


def dependency_review(root, changes):
    paths = changes['paths']
    manifest = 'clients/web/package.json'
    if manifest in paths and 'clients/web/package-lock.json' not in paths:
        try:
            before = subprocess.check_output(['git', 'show', f"{changes['merge_base']}:{manifest}"], cwd=root, stderr=subprocess.DEVNULL)
            staged = subprocess.check_output(['git', 'show', f':{manifest}'], cwd=root, stderr=subprocess.DEVNULL)
            current = (root / manifest).read_bytes()
            if web_dependency_change(before, staged) or web_dependency_change(before, current):
                return ('BLOCKED: Web dependency declarations changed without a lockfile diff; '
                        'verify with npm ci --prefix clients/web --ignore-scripts and explain any valid exception.')
        except (OSError, ValueError, subprocess.CalledProcessError):
            return 'BLOCKED: Cannot compare Web manifest versions; review lockfile and deletion or addition manually.'
    for manifest, lock in [('backend/go.mod', 'backend/go.sum'),
                           ('clients/flutter/pubspec.yaml', 'clients/flutter/pubspec.lock')]:
        if manifest in paths and lock not in paths:
            return f'BLOCKED: {manifest} changed without {lock}; review dependency semantics and any valid exception.'
    return 'Review all applicable manifest/lockfile pairs.'
