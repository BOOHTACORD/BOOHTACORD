"""Exact browser observation graph for the owned live installation acceptance."""
import json
from pathlib import Path
import re

PHASES=json.loads((Path(__file__).parent/'phases.json').read_text())


def validate_observations(rows, baseline, next_source):
    if (any(not isinstance(v,str) or not re.fullmatch('[a-f0-9]{40}',v) for v in (baseline,next_source))
            or baseline==next_source or not isinstance(rows,list) or len(rows)!=len(PHASES)*2):
        raise ValueError('Complete two-source browser evidence is required')
    sources={'baseline':baseline,'next':next_source}
    if not all(isinstance(row,dict) for row in rows):raise ValueError('Malformed browser evidence')
    policy=rows[0].get('permissions_sha256')
    if not isinstance(policy,str) or not re.fullmatch('[a-f0-9]{64}',policy):
        raise ValueError('Actual preserved role policy fingerprint is required')
    for index,phase in enumerate(PHASES):
        name=phase['name']; maintenance=name.endswith('_maintenance')
        for browser in range(2):
            expected={'phase':name,'browser':browser,'authenticated':True,'banner':maintenance,
                      'admission':503 if maintenance else 201,
                      'login_status':503 if maintenance else 204 if name in ('baseline','restored') else None,
                      'permissions_sha256':policy,'policy_unchanged':True,'member_admin_status':403,
                      'admin_dm_history_status':404,'admin_dm_attachment_status':404,
                      'revision':sources[phase['source']]}
            row=rows[index*2+browser]
            if (row!=expected or type(row.get('browser')) is not int
                    or row.get('authenticated') is not True or row.get('banner') is not maintenance
                    or row.get('policy_unchanged') is not True):
                raise ValueError('Missing, private or inconsistent browser evidence')
