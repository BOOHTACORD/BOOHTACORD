"""Enforce selected SDKs and public versioned cache inputs without bypassing tests."""
import yaml
from .spec import ROOT, approved_versions

NPM = {'ci-frontend.yaml', 'client-lifecycle-acceptance.yaml',
       'next-client-acceptance.yaml', 'qa-compatible-rollback.yaml'}


def validate(documents, root):
    versions = approved_versions(root)
    for name, workflow in documents.items():
        for job in workflow['jobs'].values():
            steps = job.get('steps', [])
            for index, step in enumerate(steps):
                reference = step.get('uses', '')
                inputs = step.get('with', {})
                kind = 'go' if reference.startswith('actions/setup-go@') else ('npm' if reference.startswith('actions/setup-node@') and name in NPM else None)
                if kind:
                    if (inputs.get('cache-dependency-path') != '.out/ci/cache-inputs/' + kind + '.json'
                            or index == 0 or steps[index - 1].get('if') is not None
                            or steps[index - 1].get('run') not in
                            ('python -m tools.ci.toolchains.cache_inputs ' + kind,
                             'python3 -m tools.ci.toolchains.cache_inputs ' + kind)):
                        raise ValueError('Public SDK/lockfile/OS/arch inputs required before cache restore')
                if reference.startswith('actions/setup-go@'):
                    if inputs.get('go-version') != versions['go'] or 'go-version-file' in inputs:
                        raise ValueError('Go cache and installed SDK must select the approved toolchain')
                if reference.startswith('actions/setup-node@'):
                    if inputs.get('node-version-file') != '.node-version' or 'node-version' in inputs:
                        raise ValueError('Approved Node version file required')
                    if name in NPM and inputs.get('cache') != 'npm':
                        raise ValueError('Locked npm content cache required')
                if reference == './.github/actions/flutter-setup':
                    if inputs != {'channel': 'stable', 'flutter-version': versions['flutter'], 'cache': 'true'}:
                        raise ValueError('Reviewed Flutter SDK inputs required')
                command = step.get('run', '')
                if 'npm ci' in command and (step.get('if') is not None or name not in NPM):
                    raise ValueError('Cache state must not suppress locked dependency installation')
                if 'tools.ci.web_suites.run' in command and step.get('if') is not None:
                    raise ValueError('Cache state must not suppress a complete locked Web profile')
                if 'playwright install' in command and '--with-deps chromium' not in command:
                    raise ValueError('Browser binaries cannot replace required OS dependencies')


def main():
    documents = {p.name: yaml.load(p.read_text(), Loader=yaml.BaseLoader)
                 for p in (ROOT / '.github/workflows').glob('*.yaml')}
    validate(documents, ROOT)
    print('PASS: exact Go/Node/Flutter SDKs and public cache inputs; unconditional locked installs')


if __name__ == '__main__':
    main()
