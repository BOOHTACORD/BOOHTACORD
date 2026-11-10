"""Read and compare current GitHub Release, assets and peeled tag."""
import re

from tools.product_map.release.github_api import read_api
from .match import match_live_release


def verify_release(evidence, tag, token):
    if (not isinstance(tag, str) or
            not re.fullmatch(r'(windows|macos|android)-v\d+\.\d+\.\d+', tag) or
            type(evidence.get('github_release_id')) is not int or
            evidence['github_release_id'] <= 0):
        raise ValueError('invalid release identity')
    release = read_api(f'/releases/{evidence["github_release_id"]}', token)
    ref = read_api('/git/ref/tags/' + tag, token)
    try:
        if ref['ref'] != 'refs/tags/' + tag:
            raise ValueError('release tag reference differs')
        obj = ref['object']
        seen = set()
        for _ in range(5):
            if obj['type'] != 'tag':
                break
            sha = obj['sha']
            if not re.fullmatch(r'[0-9a-f]{40}', sha) or sha in seen:
                raise ValueError('invalid annotated tag chain')
            seen.add(sha)
            obj = read_api('/git/tags/' + sha, token)['object']
        if obj['type'] != 'commit' or not re.fullmatch(r'[0-9a-f]{40}', obj['sha']):
            raise ValueError('tag does not resolve to a commit')
        return match_live_release(evidence, tag, release, obj['sha'])
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError('incomplete GitHub tag metadata') from error
