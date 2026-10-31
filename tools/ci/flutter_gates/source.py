"""Public execution identity and exact tracked source for isolated CI jobs."""
import re
from tools.ci.native.process import ROOT, output


def context(env):
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('GITHUB_REPOSITORY') != 'BOOHTACORD/BOOHTACORD'
            or not re.fullmatch('[0-9a-f]{40}', env.get('GITHUB_SHA', ''))
            or not re.fullmatch('[a-z][a-z0-9-]{0,47}', env.get('FLUTTER_EVIDENCE_NAMESPACE', ''))
            or any(not re.fullmatch('[1-9][0-9]{0,19}', env.get(key, ''))
                   for key in ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'))):
        raise ValueError('Exact upstream source and finite Actions run/attempt required')
    return env['GITHUB_SHA'], env['GITHUB_RUN_ID'], env['GITHUB_RUN_ATTEMPT'], env['FLUTTER_EVIDENCE_NAMESPACE']


def verify(expected):
    revision = output('git', 'rev-parse', 'HEAD', cwd=ROOT)
    dirty = output('git', 'status', '--porcelain', '--untracked-files=no', cwd=ROOT)
    if revision != expected or dirty:
        raise ValueError('Flutter CI evidence requires the exact clean tracked source')
