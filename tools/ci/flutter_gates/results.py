"""Require both complete native profiles and their mandatory measured artifacts."""
import json
import math
import re
from tools.ci.native.process import ROOT
from .profiles import OPERATIONS
from .artifacts import VISUALS

FIELDS = {'schema_version', 'source_revision', 'profile', 'run_id', 'run_attempt', 'namespace',
          'status', 'completed', 'seconds', 'sdk', 'artifacts'}
ANDROID_FILES = {'app-debug.apk', 'artifact-manifest.json', 'SHA256SUMS'}


def expected_sdk():
    versions = json.loads((ROOT / 'tools/toolchains.json').read_text())
    source = json.loads((ROOT / 'tools/ci/flutter_setup/source.json').read_text())
    return {'flutter': versions['flutter'], 'dart': versions['dart'],
            'framework_revision': source['framework_revision']}


def validate_artifacts(profile, measured):
    required = (set(VISUALS) if profile == 'dart' else set() if profile == 'android-kotlin' else ANDROID_FILES)
    allowed = required if profile != 'android' else required | {'LICENSE-RNNoise.txt', 'rnnoise-component.cdx.json'}
    if not isinstance(measured, dict) or not required <= set(measured) <= allowed:
        raise ValueError('Mandatory native artifact evidence is missing or unexpected')
    for item in measured.values():
        if (not isinstance(item, dict) or set(item) != {'bytes', 'sha256'}
                or type(item['bytes']) is not int or not 0 < item['bytes'] <= 256 * 1024 * 1024
                or not isinstance(item['sha256'], str) or not re.fullmatch('[0-9a-f]{64}', item['sha256'])):
            raise ValueError('Public native artifact needs a measured finite size and digest')


def validate(parts, needs, source, run_id, attempt, namespace='flutter'):
    if (not isinstance(needs, dict) or set(needs) != set(OPERATIONS)
            or any(not isinstance(v, dict) or v.get('result') != 'success' for v in needs.values())
            or not isinstance(parts, list) or len(parts) != len(OPERATIONS)):
        raise ValueError('All native profile jobs must succeed')
    seen = {}
    for part in parts:
        if (not isinstance(part, dict) or set(part) != FIELDS
                or type(part['schema_version']) is not int or part['schema_version'] != 1
                or part['profile'] not in OPERATIONS or part['profile'] in seen
                or part['source_revision'] != source or part['run_id'] != run_id
                or part['run_attempt'] != attempt or part['namespace'] != namespace or part['status'] != 'PASS'
                or part['completed'] != list(OPERATIONS[part['profile']])
                or part['sdk'] != expected_sdk()
                or type(part['seconds']) not in (int, float)
                or not math.isfinite(part['seconds']) or not 0 < part['seconds'] < 3600):
            raise ValueError('Native profile source, execution, SDK or coverage differs')
        validate_artifacts(part['profile'], part['artifacts'])
        seen[part['profile']] = part
    return seen
