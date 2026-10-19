"""Exact reviewed Apple toolchain; an unavailable native host is BLOCKED, never green."""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import subprocess
from tools.ci.native.process import ROOT

POLICY=Path(__file__).with_name('host-v1.json')


def require(value):
    if not value:raise ValueError('Native macOS host/toolchain is unavailable or differs from policy')


def validate(row,arch):
    policy=json.loads(POLICY.read_text())
    require(arch in policy['runners'] and row.get('system')=='Darwin'
            and row.get('architecture')==('arm64' if arch=='arm64' else 'x86_64')
            and re.fullmatch(str(policy['os_major'])+r'\.[0-9]+(?:\.[0-9]+)?',row.get('os_version','')))
    require(all(row.get(key)==policy[key] for key in ('xcode_version','xcode_build','macos_sdk')))
    return row


def command(*args,env=None):return subprocess.check_output(args,text=True,stderr=subprocess.DEVNULL,timeout=20,env=env).strip()


def inspect(arch,*,select=False):
    policy=json.loads(POLICY.read_text());directory=policy['developer_directory']
    require(platform.system()=='Darwin' and Path(directory).is_dir())
    if not select:require(os.environ.get('DEVELOPER_DIR')==directory)
    env=dict(os.environ,DEVELOPER_DIR=directory)
    raw=command('xcodebuild','-version',env=env);match=re.fullmatch(r'Xcode ([0-9.]+)\nBuild version ([A-Za-z0-9]+)',raw);require(match)
    row=dict(system=platform.system(),architecture=platform.machine(),os_version=platform.mac_ver()[0],
             xcode_version=match[1],xcode_build=match[2],macos_sdk=command('xcrun','--sdk','macosx','--show-sdk-version',env=env))
    validate(row,arch)
    if select:
        require(os.environ.get('GITHUB_ACTIONS')=='true' and os.environ.get('RUNNER_ENVIRONMENT')=='github-hosted')
        with Path(os.environ['GITHUB_ENV']).open('a') as stream:stream.write('DEVELOPER_DIR='+directory+'\n')
    return row


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--arch',choices=['arm64','x64'],default='arm64');args=parser.parse_args()
    path=ROOT/'.out/ci/macos-host.json';path.parent.mkdir(parents=True,exist_ok=True)
    row=dict(status='BLOCKED',physical_acceptance='NOT_RUN')
    try:row.update(inspect(args.arch,select=True),status='PASS')
    except Exception:
        raise SystemExit('BLOCKED: reviewed native macOS host/toolchain unavailable') from None
    finally:path.write_text(json.dumps(row,sort_keys=True)+'\n')


if __name__=='__main__':main()
