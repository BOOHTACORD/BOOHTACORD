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
    from tools.qa.next_client_acceptance.diagnostics import validate
    from tools.qa.next_client_acceptance.browser_diagnostics import validate_context, validate_dom
    source = root/'.out/next-client-acceptance'
    pending = []
    for name, target, validator, limit in (
            ('controller-failure.json', 'next-controller.json', validate, 1024),
            ('browser-failure.json', 'next-browser.json', validate_context, 4096),
            ('failure.json', 'next-dom.json', validate_dom, 4096)):
        path = source/name
        if not path.exists() and not path.is_symlink(): continue
        require(path.is_file() and not path.is_symlink() and not any(p.is_symlink() for p in path.parents)
                and 0 < path.stat().st_size <= limit)
        value = validator(strict_json(path.read_bytes()))
        # Serialize validated finite fields, never raw private bytes or log tails.
        pending.append((target, (json.dumps(value, sort_keys=True)+'\n').encode()))
    image = source/'failure.png'
    if image.exists() or image.is_symlink():
        require(image.is_file() and not image.is_symlink() and not any(p.is_symlink() for p in image.parents)
                and 33 <= image.stat().st_size <= 16_000_000)
        raw = image.read_bytes()
        require(raw.startswith(b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR')
                and 0 < int.from_bytes(raw[16:20], 'big') <= 4096
                and 0 < int.from_bytes(raw[20:24], 'big') <= 4096)
        pending.append(('next-browser.png', raw))
    if not pending: return []
    folder = destination/'diagnostics'; folder.mkdir(parents=True, exist_ok=True)
    require(not any(p.is_symlink() for p in folder.parents) and not folder.is_symlink())
    rows=[]
    for name, raw in pending:
        target=folder/name
        require(not target.exists() and not target.is_symlink())
        target.write_bytes(raw)
        rows.append({'path': 'diagnostics/'+name, 'sha256': hashlib.sha256(raw).hexdigest()})
    return rows


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
