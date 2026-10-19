"""Check selected runtime artifacts, their original receipts and every retained byte."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
from tools.ci.artifact_policy.capture_data import safe_json,strict_json,logical_path
from .plan import require
from .validation import profiles,validate_result


def read(path,limit=2_000_000):
    require(path.is_file() and not path.is_symlink() and not any(p.is_symlink() for p in path.parents) and 0<path.stat().st_size<=limit)
    return path.read_bytes()


def verify(root,selected,source,run,attempt):
    require(root.is_dir() and not root.is_symlink() and set(p.name for p in root.iterdir())==set(selected))
    namespaces=set()
    for profile in selected:
        folder=root/profile;require(folder.is_dir() and not folder.is_symlink());result=validate_result(strict_json(read(folder/'result.json')),profile,source,run,attempt)
        require(result['port_namespace'] not in namespaces);namespaces.add(result['port_namespace'])
        expected={'result.json'};total=0
        for receipt in result['reports']:
            relative='reports/'+receipt['path'].removeprefix('.out/');logical_path(relative);expected.add(relative)
            raw=read(folder/relative);total+=len(raw);require(hashlib.sha256(raw).hexdigest()==receipt['sha256'])
            value=strict_json(raw);safe_json(value)
            require(value.get('status')=='PASS' and value.get('owned_resources_removed') is True
                    and value.get('source_revision',value.get('harness_revision'))==source and value.get('mocks') is not True)
        require(len(result['captures'])<=2000)
        for capture in result['captures']:
            logical_path(capture['path']);digest=capture['sha256'];require(re.fullmatch('[0-9a-f]{64}',digest))
            relative='captures/'+digest+'.png';expected.add(relative)
            raw=read(folder/relative,16_000_000);total+=len(raw)
            require(raw.startswith(b'\x89PNG\r\n\x1a\n') and len(raw)==capture['bytes'] and hashlib.sha256(raw).hexdigest()==digest)
        require(total<=512_000_000)
        actual=set()
        for path in folder.rglob('*'):
            require(not path.is_symlink())
            if path.is_file():actual.add(path.relative_to(folder).as_posix())
        require(actual==expected)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--profiles',required=True);args=parser.parse_args()
    verify(Path('.out/actual-download'),profiles(args.profiles),os.environ['GITHUB_SHA'],os.environ['GITHUB_RUN_ID'],os.environ['GITHUB_RUN_ATTEMPT'])
    print('PASS: selected original actual controllers, source, captures and cleanup; release/physical NOT_RUN')


if __name__=='__main__':main()
