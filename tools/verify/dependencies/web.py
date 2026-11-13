"""Resolve local TS/Vue imports and enforce shared/feature/composition direction."""
import posixpath
import json
import subprocess
from pathlib import Path

SRC = 'clients/web/src/'
SHARED = {'config', 'validation', 'design', 'telemetry', 'shared'}
ROOTS = {'App.vue', 'main.ts', 'workspace'}
WORKLET = SRC + 'voice/noise_suppression/deepfilter/worklet.js'
STAGER = 'tools/audio/research_dfn_web/stage.mjs'
BUILDER = 'tools/audio/research_dfn_web/build.py'
GENERATED = {'./core.js': (SRC + 'voice/noise_suppression/deepfilter/core.ts', STAGER),
             './dfn.js': (BUILDER, STAGER)}


def owner(path):
    return path.removeprefix(SRC).split('/')[0]


def violations(sources):
    errors = []
    for path, imports in sources.items():
        if not path.endswith(('.ts', '.vue', '.js', '.css')):
            continue
        for uri in imports:
            if not uri.startswith('.'):
                continue
            base = posixpath.normpath(posixpath.join(posixpath.dirname(path), uri.split('?')[0]))
            if path == WORKLET and uri in GENERATED:
                required = GENERATED[uri]
                target = required[0] if all(value in sources for value in required) else None
            else:
                substitution = [base[:-3] + '.ts'] if path.endswith(('.ts', '.vue')) and base.endswith('.js') else []
                candidates = [*substitution, base, *(base + suffix for suffix in ('.ts', '.vue', '.js', '.json', '/index.ts'))]
                target = next((value for value in candidates if value in sources), None)
            if target is None:
                errors.append(f'{path}: missing local dependency: {uri}')
                continue
            if path.endswith('.spec.ts'):
                continue
            caller, called = owner(path), owner(target)
            if caller in SHARED and called not in SHARED:
                errors.append(f'{path}: shared utility imports feature/composition: {target}')
            elif caller not in ROOTS and called in ROOTS:
                errors.append(f'{path}: feature imports root composition: {target}')
    return errors


def main():
    root = Path(__file__).resolve().parents[3]
    sources = json.loads(subprocess.check_output(['node', 'tools/verify/dependencies/web_imports.mjs'], cwd=root))
    errors = violations(sources)
    if errors:
        raise RuntimeError('\n'.join(errors))
    print(f'Web local imports and shared/feature/composition boundaries: OK ({len(sources)} files)')


if __name__ == '__main__':
    main()
