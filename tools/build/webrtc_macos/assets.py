"""Recheck the complete immutable SDK candidate immediately before privileged publication."""
import json
import os
from pathlib import Path
from . import contract,execution

NAMES=('WebRTC-macos.xcframework.zip','sdk-manifest.json','SHA256SUMS')


def verify(directory,identity):
    contract.require(directory.is_dir() and not directory.is_symlink())
    row=json.loads((directory/'sdk-manifest.json').read_text())
    contract.require(all(row.get(k)==v for k,v in dict(contract.inputs(),**identity).items())
                     and row.get('signing')=='adhoc-framework-not-notarized' and row.get('physical_playback_smoke')=='NOT_RUN')
    contract.validate_matrix(row.get('architectures'),identity['builder_revision'],identity['run_id'],identity['run_attempt'])
    archive=directory/'WebRTC-macos.xcframework.zip';contract.require(contract.digest(archive)==row.get('xcframework_sha256'))
    contract.require((directory/'SHA256SUMS').read_text()==row['xcframework_sha256']+'  '+archive.name+'\n')
    assets={}
    for name in NAMES:
        path=directory/name;contract.require(path.is_file() and not path.is_symlink() and 0<path.stat().st_size<=95_000_000)
        assets[name]=dict(sha256=contract.digest(path),bytes=path.stat().st_size)
    contract.require(not any(p.is_file() and p.name not in NAMES for p in directory.iterdir()))
    return dict(status='PASS',schema_version=1,repository='BOOHTACORD/BOOHTACORD',**identity,version=row['version'],
                recipe_sha256=row['recipe_sha256'],assets=assets,physical_playback_smoke='NOT_RUN')


def main():
    from tools.ci.native.process import ROOT
    identity=execution.context();directory=ROOT/'.out/sdk-publish'
    value=verify(directory,identity);(ROOT/'.out/sdk-contract.json').write_text(json.dumps(value,sort_keys=True)+'\n')


if __name__=='__main__':main()
