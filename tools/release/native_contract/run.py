"""One preflight/asset-contract command, retaining public source-bound release metadata."""
import argparse
import json
import os
from pathlib import Path
from tools.ci.native.process import ROOT
from .source import PLATFORMS, preflight
from .assets import validate


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('operation',choices=('preflight','assets'))
    parser.add_argument('platform',choices=PLATFORMS)
    parser.add_argument('--directory',type=Path,default=ROOT/'clients/flutter/build/release-assets')
    args=parser.parse_args()
    directory=ROOT/'.out/native-release'/args.platform;directory.mkdir(parents=True,exist_ok=True)
    path=directory/('source.json' if args.operation=='preflight' else 'contract.json')
    path.write_text('{"status":"FAIL"}\n',encoding='utf-8')
    context=preflight(args.platform)
    if args.operation=='preflight' and os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf-8') as output:
            output.write('tag='+context['tag']+'\n')
    value=context if args.operation=='preflight' else validate(args.directory,context)
    path.write_text(json.dumps(value,sort_keys=True,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
