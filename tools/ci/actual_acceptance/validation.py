"""Validate only source/run-bound actual receipts; physical/release gates stay separate."""
import re
from .plan import require,document,PROFILES
from .catalog import REPORTS


def profiles(raw):
    import json
    value=json.loads(raw)
    require(isinstance(value,list) and value and value==[p for p in PROFILES if p in value])
    return value


def validate_result(row,profile,source,run,attempt):
    require(isinstance(row,dict) and row.get('schema_version')==1 and row.get('status')=='PASS'
            and row.get('scope')=='automatic-PR-real-runtime' and row.get('profile')==profile
            and row.get('source_revision')==source and row.get('run_id')==run and row.get('run_attempt')==attempt
            and row.get('map_sha256')==document()[1] and row.get('owned_resources_removed') is True
            and row.get('release_acceptance')=='NOT_RUN' and row.get('physical_acceptance')=='NOT_RUN')
    owner=row.get('owner','');job=row.get('job','')
    require(re.fullmatch('qa-client-[0-9a-f]{16}',owner) and re.fullmatch('[A-Za-z0-9_-]{1,100}',job)
            and row.get('port_namespace') in {prefix+run+'/'+attempt+'/'+job+'/'+owner.removeprefix('qa-client-')
                for prefix in ('disposable-github-hosted-vm/','disposable-self-hosted-guest/')})
    reports=row.get('reports');captures=row.get('captures')
    require(isinstance(reports,list) and [r.get('path') for r in reports]==REPORTS[profile])
    require(all(re.fullmatch('[0-9a-f]{64}',r.get('sha256','')) for r in reports))
    require(isinstance(captures,list) and (profile=='sfu' or bool(captures)))
    return row
