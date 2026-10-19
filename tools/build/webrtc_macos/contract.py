"""Versioned source, recipe, patch, native ABI and execution identity for each SDK slice."""
import hashlib
import json
from pathlib import Path
import re
from tools.ci.macos.host import POLICY

ROOT=Path(__file__).resolve().parents[3]
RECIPE=Path(__file__).with_name('recipe.json')
PATCHES=ROOT/'clients/flutter/packages/flutter_webrtc/third_party/patches'


def require(value):
    if not value:raise ValueError('SDK source, recipe, architecture, tests or immutable receipt differs')


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs():
    raw=RECIPE.read_bytes();recipe=json.loads(raw)
    require(recipe['architectures']==['arm64','x64'] and re.fullmatch('webrtc-m150-boohtacord-r[1-9][0-9]*',recipe['version']))
    require(all(re.fullmatch('[0-9a-f]{40}',recipe[k]) for k in ('source_revision','depot_revision')))
    patches={p.name:digest(p) for p in [PATCHES/f'webrtc-sdk-m150-custom-source-{kind}.patch' for kind in ('routing','regression')]}
    return dict(schema_version=2,platform='macos',version=recipe['version'],source_revision=recipe['source_revision'],
                depot_revision=recipe['depot_revision'],routing_marker=recipe['routing_marker'],gn_base=recipe['gn_args'],
                recipe_sha256=hashlib.sha256(raw).hexdigest(),host_policy_sha256=digest(POLICY),patches=patches)


def validate_slice(row,arch,source,run,attempt):
    expected=inputs();require(isinstance(row,dict) and all(row.get(k)==v for k,v in expected.items()))
    require(arch in ('arm64','x64') and row.get('owned_workspace_removed') is True and row.get('architecture')==arch and row.get('builder_revision')==source and row.get('run_id')==run
            and row.get('run_attempt')==attempt and row.get('native_route_tests')=='PASS'
            and row.get('native_test_count')==2 and row.get('physical_playback_smoke')=='NOT_RUN'
            and row.get('binary_architectures')==['arm64' if arch=='arm64' else 'x86_64']
            and row.get('gn_args')==expected['gn_base']+' target_cpu="'+arch+'"')
    require(re.fullmatch('[0-9a-f]{40}',source) and re.fullmatch('[1-9][0-9]*',run) and re.fullmatch('[1-9][0-9]*',attempt))
    require(all(re.fullmatch('[0-9a-f]{64}',row.get(k,'')) for k in ('framework_binary_sha256','archive_sha256','native_test_report_sha256')))
    policy=json.loads(POLICY.read_text());require(all(row.get('toolchain',{}).get(k)==policy[k] for k in ('xcode_version','xcode_build','macos_sdk')))
    return row


def validate_matrix(rows,source,run,attempt):
    require(isinstance(rows,list) and [r.get('architecture') for r in rows]==['arm64','x64'])
    for row in rows:validate_slice(row,row['architecture'],source,run,attempt)
    return rows
