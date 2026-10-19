"""Versioned risk selection uses the same Git diff/path rules as component routing."""
from fnmatch import fnmatchcase
import hashlib
import json
from pathlib import Path
from tools.ci.select_changes.selection import valid_path

PROFILES=('lifecycle','next','sfu')
PATH=Path(__file__).with_name('plan-v1.json')


def require(value):
    if not value:raise ValueError('Actual acceptance selection or evidence differs')


def document():
    raw=PATH.read_bytes();value=json.loads(raw)
    require(value['schema_version']==1 and value['profiles']==list(PROFILES))
    for row in value['rules']:
        require(row['paths'] and set(row['profiles'])<=set(PROFILES) and set(row['release'])<=set(value['release_gates'])
                and set(row['physical'])<=set(value['physical_gates']))
    return value,hashlib.sha256(raw).hexdigest()


def select(paths):
    value,digest=document();chosen=set();release=set();physical=set();uncertain=paths is None
    for path in paths or []:
        match=next((row for row in value['rules'] if valid_path(path) and any(fnmatchcase(path,p) for p in row['paths'])),None)
        if match is None:uncertain=True;break
        chosen.update(match['profiles']);release.update(match['release']);physical.update(match['physical'])
    if uncertain:chosen=set(PROFILES);release=set(value['release_gates']);physical=set(value['physical_gates'])
    return {'profiles':[p for p in PROFILES if p in chosen],'release_required':sorted(release),'physical_required':sorted(physical),
            'map_sha256':digest,'map_version':1,'uncertain':uncertain}
