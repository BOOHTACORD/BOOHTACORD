"""Public exact-source backend evidence; no database state or test output."""
import json
import math
import os
from pathlib import Path
import re

PROFILES = ('static', 'database', 'load')
OPERATIONS = {
    'static': ('go:vet:all', 'go:build:all'),
    'database': ('go:database-preflight', 'go:test:all:uncached', 'go:no-skip'),
    'load': ('screen-share:matrix', 'api:normal:2:20', 'api:reconnect:2:20',
             'api:uploads:2:20:1024', 'api:nat_auth:1:20', 'api:faults:2:40'),
}


def require(value):
    if not value:
        raise ValueError('Incomplete, foreign or unsuccessful backend evidence')


def execution():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        return {'run_id':'local', 'run_attempt':'1'}
    run_id, attempt = os.environ.get('GITHUB_RUN_ID',''), os.environ.get('GITHUB_RUN_ATTEMPT','')
    require(re.fullmatch('[1-9][0-9]{0,19}',run_id) and re.fullmatch('[1-9][0-9]{0,3}',attempt))
    return {'run_id':run_id, 'run_attempt':attempt}


def read_reports(directory):
    directory=Path(directory)
    require(directory.is_dir() and not directory.is_symlink())
    require({p.name for p in directory.iterdir()} == {name+'.json' for name in PROFILES})
    rows=[]
    for name in PROFILES:
        path=directory/(name+'.json')
        require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 65536)
        row=json.loads(path.read_text())
        require(isinstance(row,dict) and row.get('profile') == name)
        rows.append(row)
    return rows


def validate(source, needs, rows):
    try:
        require(isinstance(source,str) and re.fullmatch('[0-9a-f]{40}',source))
        require(set(needs) == set(PROFILES) and all(v.get('result') == 'success' for v in needs.values()))
        require(isinstance(rows,list) and len(rows) == len(PROFILES))
        durations={}
        for row in rows:
            require(set(row) == {'source_revision','profile','status','operations','seconds','execution'})
            name=row['profile']
            require(name in PROFILES and name not in durations and row['source_revision'] == source
                    and row['status'] == 'PASS' and row['operations'] == list(OPERATIONS[name])
                    and row['execution'] == execution())
            seconds=row['seconds']
            require(type(seconds) in (int,float) and math.isfinite(seconds) and seconds > 0)
            durations[name]=seconds
        require(set(durations) == set(PROFILES))
        return {'source_revision':source,'status':'PASS','execution':execution(),
                'observed_profile_seconds':durations,'checked_operations':sum(map(len,OPERATIONS.values()))}
    except (KeyError,TypeError,AttributeError) as error:
        raise ValueError('Malformed backend result') from error
