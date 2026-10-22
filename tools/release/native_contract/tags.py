"""Prepare one immutable canonical version tag through the protected master job."""
import argparse
import json
import os
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from tools.build.client_identity import load
from tools.ci.native.process import ROOT, output
from tools.release.native_contract.source import REPOSITORY, PLATFORMS, require


def prepare(platform, env, revision, master, version, request):
    require(platform in PLATFORMS and re.fullmatch(r'\d+\.\d+\.\d+', version))
    require(env.get('GITHUB_REPOSITORY') == REPOSITORY and
            env.get('GITHUB_EVENT_NAME') == 'workflow_dispatch' and
            env.get('GITHUB_REF') == 'refs/heads/master' and
            re.fullmatch('[0-9a-f]{40}', revision) and
            revision == master == env.get('GITHUB_SHA'))
    tag = platform + '-v' + version
    endpoint = '/git/ref/tags/' + tag
    existing = request(endpoint)
    if existing is None:
        request('/git/refs', 'POST', {'ref': 'refs/tags/' + tag, 'sha': revision})
        existing = request(endpoint)
    obj = existing.get('object', {}) if isinstance(existing, dict) else {}
    for _ in range(5):
        if obj.get('type') != 'tag':
            break
        require(re.fullmatch('[0-9a-f]{40}', obj.get('sha', '')))
        obj = request('/git/tags/' + obj['sha']).get('object', {})
    require(obj.get('type') == 'commit' and obj.get('sha') == revision)
    return {'status': 'PASS', 'tag': tag, 'source_revision': revision}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=PLATFORMS)
    args = parser.parse_args()
    output('git', 'diff', '--exit-code', 'HEAD', '--')
    token = os.environ['GITHUB_TOKEN']
    def request(path, method='GET', body=None):
        data = None if body is None else json.dumps(body).encode()
        req = Request('https://api.github.com/repos/' + REPOSITORY + path,
                      data=data, method=method, headers={
                          'Authorization': 'Bearer ' + token,
                          'Accept': 'application/vnd.github+json',
                          'Content-Type': 'application/json',
                          'User-Agent': 'BOOHTACORD-native-release'})
        try:
            with urlopen(req, timeout=30) as response:
                return json.load(response)
        except HTTPError as error:
            if method == 'GET' and path.startswith('/git/ref/tags/') and error.code == 404:
                return None
            raise RuntimeError('GitHub tag operation failed with HTTP ' + str(error.code)) from None
    result = prepare(args.platform, os.environ, output('git', 'rev-parse', 'HEAD'),
                     output('git', 'rev-parse', 'refs/remotes/origin/master'),
                     load(args.platform)['version'], request)
    destination = ROOT / '.out/native-release'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'tag-preparation.json').write_text(json.dumps(result) + '\n')
    print('Verified ' + result['tag'] + ' at ' + result['source_revision'])
    print('Dispatch the existing platform release workflow from this tag; token-created tags do not trigger push workflows.')


if __name__ == '__main__':
    main()
