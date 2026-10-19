"""The existing Windows status is mandatory even after upstream cancellation."""
import json
import os
import re
from tools.ci.native.process import ROOT, output
from .transfer import execution, require, read

ROLES={'windows-native-unit','windows-build','windows-gui-sfu'}


def validate(source,needs,row):
    require(set(needs)==ROLES and all(v.get('result')=='success' for v in needs.values()))
    require(set(row)=={'source_revision','status','execution','manifest_sha256','recovery','gui_sfu'})
    require(row['source_revision']==source and re.fullmatch('[0-9a-f]{40}',source)
            and row['status']=='PASS' and row['execution']==execution()
            and isinstance(row['manifest_sha256'],str) and re.fullmatch('[0-9a-f]{64}',row['manifest_sha256'])
            and row['recovery'] is True and row['gui_sfu'] is True)


def main():
    source=output('git','rev-parse','HEAD')
    require(os.environ.get('GITHUB_SHA',source)==source)
    validate(source,json.loads(os.environ['WINDOWS_NEEDS']),read(ROOT/'.out/ci/windows-acceptance.json'))


if __name__ == '__main__': main()
