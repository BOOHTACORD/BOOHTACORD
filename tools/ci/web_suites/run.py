"""Local and hosted entrypoint; publish only complete public profile evidence."""
import argparse
import json
import os
import subprocess
from tools.ci.native.process import ROOT, output, require_version, run
from tools.audio.asset_build import build_assets
from . import catalog, runner


def checked_source():
    source = output('git', 'rev-parse', 'HEAD')
    if os.environ.get('GITHUB_SHA', source) != source:
        raise ValueError('Web suite source differs from the checked-out revision')
    code = subprocess.run(['git', 'diff', '--exit-code', 'HEAD', '--'], cwd=ROOT,
                          stdout=subprocess.DEVNULL).returncode
    if code not in (0, 1) or (code and os.environ.get('GITHUB_ACTIONS') == 'true'):
        raise ValueError('CI Web profiles require the exact clean source; Git failures cannot pass')
    require_version('node', output('node', '--version').removeprefix('v'))
    return source, bool(code)


def execute(profile=None):
    source, dirty = checked_source()
    catalog.plan()
    directory = ROOT / '.out/ci/web-parts'
    directory.mkdir(parents=True, exist_ok=True)
    profiles = (profile,) if profile else (*catalog.PROFILES[1:], 'fast')
    for name in profiles:
        (directory / (name + '.json')).unlink(missing_ok=True)
    if not profile:
        # One installation for local serial execution; finish with the canonical
        # build/social check after network fixtures, preserving the final dist.
        runner.prepare(True, run, build_assets)
    for name in profiles:
        path = directory / (name + '.json')
        try:
            value = runner.run_profile(name, source, prepared=not bool(profile))
            final_source, final_dirty = checked_source()
            if final_source != source:
                raise ValueError('Web source revision changed during execution')
            dirty = dirty or final_dirty
            if dirty:
                value['source_revision'] = None
                value['local_worktree'] = {'base_revision':source, 'dirty':True}
        except BaseException:
            value = {'source_revision': source, 'profile': name, 'status': 'FAIL'}
            path.write_text(json.dumps(value, sort_keys=True) + '\n')
            raise
        path.write_text(json.dumps(value, sort_keys=True) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--profile', choices=catalog.PROFILES)
    args = parser.parse_args()
    execute(args.profile)


if __name__ == '__main__':
    main()
