"""Finite public source-bound runtime results and original synthetic PNG captures."""
import hashlib
import json
import shutil
from pathlib import Path
from tools.ci.artifact_policy.capture_data import safe_json, strict_json
from .plan import require
from .catalog import REPORTS,ROOTS


def collect_failure(root, profile, destination):
    if profile != 'next': return []
    path = root/'.out/next-client-acceptance/controller-failure.json'
    if not path.exists(): return []
    require(path.is_file() and not path.is_symlink() and not any(p.is_symlink() for p in path.parents)
            and 0 < path.stat().st_size <= 1024)
    from tools.qa.next_client_acceptance.diagnostics import validate
    value = validate(strict_json(path.read_bytes()))
    # Serialize validated finite fields, never raw private bytes or log tails.
    raw = (json.dumps(value, sort_keys=True)+'\n').encode()
    folder = destination/'diagnostics'; folder.mkdir(parents=True, exist_ok=True)
    require(not any(p.is_symlink() for p in folder.parents) and not folder.is_symlink())
    target = folder/'next-controller.json'
    require(not target.exists())
    target.write_bytes(raw)
    return [{'path': 'diagnostics/next-controller.json', 'sha256': hashlib.sha256(raw).hexdigest()}]


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
