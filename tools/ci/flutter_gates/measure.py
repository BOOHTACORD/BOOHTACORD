"""Read only this native shadow run's bounded parts and public scheduling data."""
import json
import os
import re
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from tools.ci.native.process import ROOT
from . import comparison, source, profiles


def read_inputs(root, sha, run_id, attempt):
    root = Path(root)
    comparison.require(root.is_dir() and not root.is_symlink() and root.resolve() == root)
    expected = {}
    for sample in (1, 2, 3):
        suffix = sha + '-' + run_id + '-' + attempt
        expected[f'flutter-legacy-shadow-old-{sample}-{suffix}'] = ('legacy', sample, 'flutter-legacy.json')
        for profile in profiles.OPERATIONS:
            expected[f'flutter-part-shadow-new-{sample}-{suffix}-{profile}'] = (profile, sample, profile + '.json')
    comparison.require({p.name for p in root.iterdir()} == set(expected))
    old, new = {}, {n: [] for n in (1, 2, 3)}
    for name, (kind, sample, filename) in expected.items():
        directory = root / name
        comparison.require(not directory.is_symlink() and directory.is_dir()
                           and {p.name for p in directory.iterdir()} == {filename})
        path = directory / filename
        comparison.require(not path.is_symlink() and path.is_file() and 0 < path.stat().st_size <= 65536)
        row = json.loads(path.read_text(encoding='utf-8'))
        if kind == 'legacy': old[sample] = row
        else: new[sample].append(row)
    return [old[n] for n in (1, 2, 3)], [new[n] for n in (1, 2, 3)]


def read_api(path):
    comparison.require(re.fullmatch(r'/actions/runs/[1-9][0-9]*(?:/jobs\?filter=latest&per_page=100)?', path))
    token = os.environ.get('GITHUB_TOKEN', '')
    comparison.require(bool(token))
    headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
               'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'boohtacord-native-shadow'}
    request = Request('https://api.github.com/repos/BOOHTACORD/BOOHTACORD' + path, headers=headers)
    try:
        with urlopen(request, timeout=30) as response: data = response.read(4 * 1024 * 1024 + 1)
    except (HTTPError, URLError, TimeoutError):
        raise RuntimeError('Read-only native shadow metadata is unavailable') from None
    comparison.require(len(data) <= 4 * 1024 * 1024)
    return json.loads(data)


def main():
    target = ROOT / '.out/ci/flutter-shadow.json'
    comparison.require(target.parent.resolve() == target.parent and not target.is_symlink())
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('{"status":"FAIL"}\n')
    sha, run_id, attempt, namespace = source.context(os.environ)
    comparison.require(namespace == 'shadow-compare')
    source.verify(sha)
    needs = json.loads(os.environ['FLUTTER_SHADOW_NEEDS'])
    comparison.require(set(needs) == {'legacy', 'profiles'} and all(v.get('result') == 'success' for v in needs.values()))
    old, new = read_inputs(ROOT / '.out/ci/flutter-shadow-inputs', sha, run_id, attempt)
    run = read_api('/actions/runs/' + run_id)
    jobs = read_api('/actions/runs/' + run_id + '/jobs?filter=latest&per_page=100')
    comparison.require(run['head_sha'] == sha and str(run['id']) == run_id and str(run['run_attempt']) == attempt)
    value = comparison.compare(run, jobs, needs, old, new)
    source.verify(sha)
    target.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    if value['status'] != 'PASS': raise SystemExit(1)
    print('PASS: complete same-source native comparison; Dart/Android timing and actual runner cost retained')


if __name__ == '__main__': main()
