"""Two isolated hosted cold/warm pairs; never cache assertions or private config."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time
from tools.ci.toolchains.spec import ROOT, approved_versions, public_bytes
from tools.ci.toolchains.cache_inputs import payload
from .results import go_tests, vitest_tests, summarize

GO_PACKAGE = './internal/media/coalesce_presence_snapshot'
WEB_FILES = ['clients/web/package.json', 'clients/web/package-lock.json', *[
    'clients/web/src/voice/network_diagnostics/' + name for name in
    ('stats.ts', 'stats.spec.ts', 'attempt.ts', 'attempt.spec.ts', 'model.ts')]]


def execute(command, cwd, env, timeout=300):
    start = time.perf_counter()
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Dependency cache observation failed; no PASS receipt produced')
    return result.stdout, round(time.perf_counter() - start, 6)


def main():
    versions = approved_versions(ROOT)
    env = os.environ.copy()
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if env.get('GITHUB_SHA', source) != source:
        raise ValueError('Cache observation source differs from checkout')
    subprocess.run(['git', 'diff', '--exit-code', 'HEAD', '--'], cwd=ROOT, check=True,
                   stdout=subprocess.DEVNULL)
    node, _ = execute(['node', '--version'], ROOT, env)
    go, _ = execute(['go', 'env', 'GOVERSION'], ROOT / 'backend', {**env, 'GOTOOLCHAIN': 'local'})
    if node.strip() != 'v' + versions['node'] or go.strip() != 'go' + versions['go']:
        raise ValueError('Actual measurement SDK differs from approved version')
    rows = {'npm': [], 'go': []}
    with tempfile.TemporaryDirectory(prefix='boohtacord-public-cache-') as temporary:
        directory = Path(temporary)
        config = directory / 'user-config'; config.write_text('')
        global_config = directory / 'global-config'; global_config.write_text('')
        web = directory / 'web'; web.mkdir()
        for name in WEB_FILES:
            target = web / Path(name).relative_to('clients/web')
            target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(public_bytes(ROOT, name))
        (web / 'fixture.config.mjs').write_bytes(public_bytes(ROOT, 'tools/ci/cache_measure/fixture.config.mjs'))
        for pair in (1, 2):
            npm_cache = directory / ('npm-' + str(pair))
            go_cache = directory / ('go-' + str(pair)); go_cache.mkdir()
            for temperature in ('cold', 'warm'):
                npm_env = {**env, 'NPM_CONFIG_CACHE': str(npm_cache),
                           'NPM_CONFIG_USERCONFIG': str(config), 'NPM_CONFIG_GLOBALCONFIG': str(global_config)}
                _, install = execute(['npm', 'ci', '--no-audit', '--no-fund'], web, npm_env)
                report = directory / 'vitest.json'
                _, check = execute(['npm', 'exec', '--', 'vitest', 'run', '--config', 'fixture.config.mjs',
                                    '--reporter=json', '--outputFile=' + str(report)], web, npm_env)
                tests = vitest_tests(json.loads(report.read_text()))
                rows['npm'].append({'pair': pair, 'temperature': temperature, 'seconds': install,
                                    'assertion_seconds': check, 'tests': tests, 'status': 'PASS'})
                go_env = {**env, 'GOTOOLCHAIN': 'local', 'GOCACHE': str(go_cache / 'build'),
                          'GOMODCACHE': str(go_cache / 'modules'), 'GOFLAGS': ''}
                output, duration = execute(['go', 'test', '-count=1', '-json', GO_PACKAGE], ROOT / 'backend', go_env)
                rows['go'].append({'pair': pair, 'temperature': temperature, 'seconds': duration,
                                   'tests': go_tests(output), 'status': 'PASS'})
    system = os.environ.get('RUNNER_OS', {'Darwin': 'macOS'}.get(platform.system(), platform.system()))
    architecture = os.environ.get('RUNNER_ARCH', {'arm64': 'ARM64', 'x86_64': 'X64'}.get(platform.machine(), ''))
    inputs = WEB_FILES + ['backend/go.mod', 'backend/go.sum', 'tools/ci/cache_measure/fixture.config.mjs']
    inputs += [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'backend/internal/media/coalesce_presence_snapshot').glob('*.go'))]
    result = {'schema_version': 1, 'source_revision': source, 'platform': system, 'architecture': architecture,
              'sdk': {'go': versions['go'], 'node': versions['node']},
              'inputs': {name: hashlib.sha256(public_bytes(ROOT, name)).hexdigest() for name in inputs},
              'cache_manifests': {kind: payload(kind, ROOT, system, architecture) for kind in ('npm', 'go')},
              'rows': rows, 'summary': {kind: summarize(values) for kind, values in rows.items()},
              'scope': 'public dependency-install/pure-test microbenchmark; four identical executions each; no full CI SLO, DB, native/media or cross-platform performance claim',
              'cache_policy': 'independent empty cache per cold pair; warm retains only that pair public npm content/Go module and build cache; npm ci recreates node_modules; go -count=1 always executes assertions; temporary configs/caches removed'}
    destination = ROOT / '.out/cache-measure'; destination.mkdir(parents=True, exist_ok=True)
    (destination / 'report.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print('PASS: two independent npm/Go cold-warm pairs; identical actual assertions and source-bound inputs')


if __name__ == '__main__':
    main()
