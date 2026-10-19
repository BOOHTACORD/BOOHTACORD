"""QA-only valid-signature immutable collision; preserve every original artifact."""
import json
from pathlib import Path
import shutil
import tarfile
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import FILES
from tools.release.bundle.signature import sign
from tools.release.bundle.verify import verify_bundle


def transport(directory, revision):
    directory=Path(directory)
    destination=directory.parent/(revision+'.release.tar.gz')
    with tarfile.open(destination,'x:gz',compresslevel=1) as archive:
        for name in sorted(FILES | {'manifest.json','manifest.json.sig'}):
            archive.add(directory/name,arcname=name,recursive=False)
    (destination.parent/(destination.name+'.sha256')).write_text(sha256(destination)+'  '+destination.name+'\n')
    return destination


def variant(original, target, private_key, public_key, revision):
    original, target=map(Path,(original,target))
    manifest=verify_bundle(original,public_key,revision)
    target.mkdir(mode=0o700,exist_ok=False)
    for name in FILES: shutil.copyfile(original/name,target/name)
    checks=target/'checks.json'
    with checks.open('ab') as stream: stream.write(b'\n ')
    manifest['files']['checks.json']={'sha256':sha256(checks),'bytes':checks.stat().st_size}
    document=target/'manifest.json'
    document.write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    sign(document,private_key)
    verify_bundle(target,public_key,revision)
    return transport(target,revision)
