"""Audit exact auxiliary SDK selections and reviewed public native inputs."""
import hashlib
import json
import re
from .spec import ROOT, public_bytes


def policy(root):
    value = json.loads(public_bytes(root, 'tools/ci/toolchains/auxiliary.json'))
    python = value.get('python')
    if (not isinstance(python, dict) or set(python) != {'Linux', 'Windows', 'macOS'}
            or any(not re.fullmatch(r'3\.12\.\d+', v) for v in python.values())
            or python['Windows'] != python['macOS']
            or not re.fullmatch(r'17\.\d+\.\d+\+\d+', value.get('java', ''))
            or not re.fullmatch(r'17\.\d+\.\d+(?:\.\d+)?\+\d+', value.get('java_runtime', ''))
            or not re.fullmatch(r'8\.0\.\d+', value.get('dotnet', ''))):
        raise ValueError('Exact reviewed per-platform Python, Java and .NET SDKs required')
    return value


def python_input(root):
    versions = policy(root)['python']
    return "${{ runner.os == 'Linux' && '" + versions['Linux'] + "' || '" + versions['Windows'] + "' }}"


def validate_workflows(documents, root):
    versions = policy(root)
    expected = {'python': ('python-version', python_input(root)),
                'java': ('java-version', versions['java']),
                'dotnet': ('dotnet-version', versions['dotnet'])}
    for workflow in documents.values():
        for job in workflow['jobs'].values():
            steps = job.get('steps', [])
            needs_python = any('python' in s.get('run', '') or s.get('uses') == './.github/actions/flutter-setup' for s in steps)
            if needs_python:
                setups = [i for i, s in enumerate(steps) if s.get('uses', '').startswith('actions/setup-python@')]
                if len(setups) != 1 or any('python' in s.get('run', '') for s in steps[:setups[0]]):
                    raise ValueError('Hosted Python commands require one prior reviewed interpreter selection')
            for index, step in enumerate(steps):
                for kind, (key, value) in expected.items():
                    if step.get('uses', '').startswith('actions/setup-' + kind + '@'):
                        inputs = step.get('with', {})
                        if inputs.get(key) != value or step.get('if') is not None:
                            raise ValueError('Auxiliary SDK must be exact and independent of cache state')
                        if kind == 'java' and inputs.get('distribution') != 'temurin':
                            raise ValueError('Reviewed Java distribution required')
                        if (index + 1 == len(steps)
                                or steps[index + 1].get('run') != 'python -m tools.ci.toolchains.runtime ' + kind
                                or steps[index + 1].get('if') is not None):
                            raise ValueError('Actual auxiliary SDK identity must be checked after selection')
                        if any(k in inputs for k in ('cache', 'cache-dependency-path')):
                            raise ValueError('Auxiliary dependency caches need independent measurement and review')


def audit(root):
    policy(root)
    from tools.ci.flutter_setup.vendor_locks import audit_public
    audit_public(root)
    manifest = json.loads(public_bytes(root, 'tools/ci/toolchains/native-inputs.json'))
    files = manifest.get('files', {})
    if manifest.get('schema_version') != 1 or not files:
        raise ValueError('Reviewed native input inventory required')
    for name, expected in files.items():
        if (not re.fullmatch(r'[0-9a-f]{64}', expected)
                or hashlib.sha256(public_bytes(root, name).replace(b'\r\n', b'\n')).hexdigest() != expected):
            raise ValueError('Native SDK/build input differs from its reviewed inventory')
    wrapper = public_bytes(root, 'clients/flutter/android/gradle/wrapper/gradle-wrapper.properties').decode().replace('\r\n', '\n')
    if not re.search(r'^distributionSha256Sum=[0-9a-f]{64}$', wrapper, re.MULTILINE):
        raise ValueError('Gradle distribution requires its official SHA256')
    sdk = json.loads(public_bytes(root, 'global.json'))
    if sdk != {'sdk': {'version': policy(root)['dotnet'], 'rollForward': 'disable', 'allowPrerelease': False}}:
        raise ValueError('.NET CLI must select the reviewed SDK without roll-forward')
    for name in ('tools/requirements-ci.txt', 'tools/verify/openapi_parity/requirements.txt'):
        lines = public_bytes(root, name).decode().splitlines()
        if any(not re.fullmatch(r'[A-Za-z0-9_.-]+==[0-9]+(?:\.[0-9]+)+', s)
               for line in lines if (s := line.strip()) and not s.startswith('#')):
            raise ValueError('Direct Python verification requirements must select exact releases')
    return manifest


def check_runtime(kind, actual, system, root):
    versions = policy(root)
    if system not in versions['python'] or kind not in ('python', 'java', 'dotnet'):
        raise ValueError('Unsupported auxiliary SDK/platform')
    expected = versions[kind][system] if kind == 'python' else versions['java_runtime' if kind == 'java' else kind]
    if actual != expected:
        raise ValueError('Installed auxiliary SDK differs from the reviewed platform policy')


def main():
    import yaml
    audit(ROOT)
    documents = {p.name: yaml.load(p.read_text(), Loader=yaml.BaseLoader)
                 for p in (ROOT / '.github/workflows').glob('*.yaml')}
    validate_workflows(documents, ROOT)
    print('PASS: auxiliary SDK declarations and reviewed native build inputs')


if __name__ == '__main__':
    main()
