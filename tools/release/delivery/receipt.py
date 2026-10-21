"""Finite public delivery evidence; no raw command output, exceptions or credentials."""
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
from tools.release.install.diagnostics import INSTALL_PHASES
from .phases import LIMITS
from .readback_contract import validate as acknowledgement, unique

STEPS = ('controller', 'producer', 'download', 'recheck', 'ssh', 'install')
CODES = {'start', 'exit', 'timeout', 'output', 'cleanup', 'invalid_output', 'execution', 'interrupted'}
INSTALL_FAILURE_CODES = {'installer_' + phase for phase in INSTALL_PHASES}
BASE = {'schema_version', 'kind', 'source_revision', 'controller_revision', 'status', 'phases'}


def checked(value):
    if not isinstance(value, dict) or set(value) not in (BASE, BASE|{'readback'}): raise ValueError
    if (type(value['schema_version']) is not int or value['schema_version'] != 1
            or value['kind'] != 'delivery-phases' or value['status'] not in ('PASS','FAIL')): raise ValueError
    for key in ('source_revision', 'controller_revision'):
        if not isinstance(value[key], str) or not re.fullmatch('[a-f0-9]{40}',value[key]): raise ValueError
    rows = value['phases']
    if not isinstance(rows,list) or len(rows)>len(LIMITS): raise ValueError
    failed = False
    for index,row in enumerate(rows):
        name = tuple(LIMITS)[index]
        if (not isinstance(row,dict) or set(row) != {'phase','limit_seconds','status','failure_code','exit_code','elapsed_seconds'}
                or row['phase'] != name or type(row['limit_seconds']) is not int or row['limit_seconds'] != LIMITS[name]
                or failed or row['status'] not in ('PASS','FAIL')): raise ValueError
        elapsed=row['elapsed_seconds']
        if type(elapsed) not in (int,float) or not math.isfinite(elapsed) or not 0<=elapsed<=1800: raise ValueError
        if row['status']=='PASS':
            if row['failure_code'] is not None or row['exit_code'] is not None: raise ValueError
        else:
            failed=True
            code=row['exit_code']
            if code is not None and (type(code) is not int or not -255<=code<=255): raise ValueError
            if row['failure_code'] in INSTALL_FAILURE_CODES:
                if name != 'remote_install' or code is not None: raise ValueError
            elif row['failure_code'] not in CODES: raise ValueError
    if value['status']=='PASS':
        if failed or len(rows)!=len(LIMITS) or 'readback' not in value: raise ValueError
        readback=value['readback']
        acknowledgement(json.dumps(readback).encode(),value['source_revision'],value['controller_revision'],
                        readback['previous_source_revision'],readback['nonce'])
    elif 'readback' in value: raise ValueError
    return value


def build(outcomes, transfer):
    stages={name:outcomes.get(name) if outcomes.get(name) in ('success','failure','skipped','cancelled') else 'unknown' for name in STEPS}
    value={'schema_version':1,'kind':'production-delivery','status':'FAIL','human_approval':'NOT_ASSERTED',
           'stages':stages,'remote_completion':'UNKNOWN'}
    try: delivery=checked(transfer)
    except Exception: return value
    value['delivery']=delivery
    if delivery['status']=='PASS' and all(v=='success' for v in stages.values()):
        value.update(status='PASS',remote_completion='FRESH_READBACK_VERIFIED')
    return value


def document(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_nlink!=1 or not 0<path.stat().st_size<=65536:
        return None
    try: return json.loads(path.read_bytes(),object_pairs_hook=unique)
    except Exception: return None


def authority(value):
    keys={'id','name','size_in_bytes','digest','source_revision','run_id','run_attempt','format_version'}
    if not isinstance(value,dict) or set(value)!=keys: raise ValueError
    for key in ('id','size_in_bytes','run_id','run_attempt','format_version'):
        if type(value[key]) is not int or value[key]<=0: raise ValueError
    source=value['source_revision']
    if not isinstance(source,str) or not re.fullmatch('[a-f0-9]{40}',source) or value['format_version'] not in (1,2): raise ValueError
    expected=f'server-{source}'+(f'-{value["run_id"]}-{value["run_attempt"]}' if value['format_version']==2 else '')
    if value['name']!=expected: raise ValueError
    digest=value['digest']
    if digest is None and value['format_version']==1: return value
    if not isinstance(digest,str) or not re.fullmatch('sha256:[a-f0-9]{64}',digest): raise ValueError
    return value


def main():
    root=Path.cwd()/'.out/delivery'; root.mkdir(parents=True,exist_ok=True)
    value=build({name:os.environ.get('STEP_'+name.upper()) for name in STEPS},document(root/'transfer.json'))
    try:
        producer=authority(document(root/'producer.json'))
        if value.get('delivery',{}).get('source_revision')!=producer['source_revision']: raise ValueError
        value['producer']=producer
    except Exception: value['status']='FAIL'
    value['checked_at']=datetime.now(timezone.utc).isoformat()
    (root/'receipt.json').write_text(json.dumps(value,sort_keys=True)+'\n',encoding='utf-8')
    print('Sanitized delivery receipt written: '+value['status'])


if __name__=='__main__': main()
