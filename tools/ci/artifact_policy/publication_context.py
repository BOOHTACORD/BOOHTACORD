"""Synthetic publication is limited to clean, exact-source hosted Linux jobs."""
from tools.ci.native.process import output
from . import capture_data as data


def checked(env, component, profile, *, git=None):
    data.require(env.get('GITHUB_ACTIONS') == 'true'
                 and env.get('RUNNER_ENVIRONMENT') == 'github-hosted'
                 and env.get('RUNNER_OS') == 'Linux'
                 and component in ('web', 'flutter'))
    namespace = 'WEB_NAMESPACE' if component == 'web' else 'FLUTTER_EVIDENCE_NAMESPACE'
    identity = {'repository': env.get('GITHUB_REPOSITORY'), 'source_revision': env.get('GITHUB_SHA'),
                'run_id': env.get('GITHUB_RUN_ID'), 'run_attempt': env.get('GITHUB_RUN_ATTEMPT'),
                'namespace': env.get(namespace), 'component': component,
                'profile': profile, 'platform': 'linux'}
    data.identity(identity)
    git = git or (lambda *args: output('git', *args))
    data.require(git('rev-parse', 'HEAD') == identity['source_revision']
                 and git('status', '--porcelain', '--untracked-files=no') == '')
    return identity
