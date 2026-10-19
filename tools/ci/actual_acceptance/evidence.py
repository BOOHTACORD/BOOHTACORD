"""Finite public source-bound runtime results and original synthetic PNG captures."""
import hashlib
import json
import shutil
from pathlib import Path
from tools.ci.artifact_policy.capture_data import safe_json
from .plan import require
from .catalog import REPORTS,ROOTS


def collect(root,profile,source,destination):
    rows=[]
    for relative in REPORTS[profile]:
        path=root/relative
        require(path.is_file() and not path.is_symlink() and not any(p.is_symlink() for p in path.parents) and 0<path.stat().st_size<=2_000_000)
        value=json.loads(path.read_text());safe_json(value)
        require(value.get('status')=='PASS' and value.get('owned_resources_removed') is True
                and value.get('source_revision',value.get('harness_revision'))==source and value.get('mocks') is not True)
        rows.append({'path':relative,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        target=destination/'reports'/relative.removeprefix('.out/');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
    captures=[];total=0
    for base in ROOTS[profile]:
        for path in sorted((root/base).rglob('*.png')):
            require(path.is_file() and not path.is_symlink() and not any(p.is_symlink() for p in path.parents) and 0<path.stat().st_size<=16_000_000)
            raw=path.read_bytes();require(raw.startswith(b'\x89PNG\r\n\x1a\n'))
            total+=len(raw);require(total<=512_000_000 and len(captures)<2000)
            digest=hashlib.sha256(raw).hexdigest();relative=path.relative_to(root).as_posix()
            folder=destination/'captures';folder.mkdir(exist_ok=True)
            target=folder/(digest+'.png')
            if not target.exists():target.write_bytes(raw)
            captures.append({'path':relative,'sha256':digest,'bytes':len(raw)})
    if profile in ('lifecycle','next'):require(captures)
    return {'reports':rows,'captures':captures}
