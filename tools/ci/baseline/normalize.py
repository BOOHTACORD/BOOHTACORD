"""Allowlisted public scheduling metadata. No actors, payloads, logs or input values."""
import re

REPO = 'BOOHTACORD/BOOHTACORD'
RUN_FIELDS = ('id', 'head_sha', 'path', 'event', 'status', 'conclusion', 'run_attempt',
              'created_at', 'run_started_at')
JOB_FIELDS = ('id', 'name', 'status', 'conclusion', 'created_at', 'started_at', 'completed_at')
STEP_FIELDS = ('name', 'number', 'status', 'conclusion', 'started_at', 'completed_at')
NA = 'N/A: not exposed by metadata API'


def fields(raw, names):
    result = {k: raw.get(k) for k in names}
    for key in ('name', 'path'):
        if isinstance(result.get(key), str):
            result[key] = re.sub(r'[\x00-\x1f\x7f]', '', result[key])[:240]
    return result


def normalize_run(raw):
    result = fields(raw, RUN_FIELDS)
    result['url'] = f'https://github.com/{REPO}/actions/runs/{raw["id"]}'
    event = raw.get('event')
    result['ref_kind'] = ('pull_request' if event == 'pull_request' else 'master'
                          if raw.get('head_branch') == 'master' else 'manual' if event == 'workflow_dispatch' else 'tag_or_other')
    return result


def normalize_job(raw):
    result = fields(raw, JOB_FIELDS)
    labels = ' '.join(raw.get('labels') or []).lower()
    result['platform'] = next((p for p in ('windows', 'macos', 'ubuntu') if p in labels), 'unknown')
    result['cache_state'] = NA
    result['steps'] = []
    for step in raw.get('steps', []):
        item = fields(step, STEP_FIELDS)
        name = (item.get('name') or '').lower()
        item['kind'] = ('artifact_upload' if any(s in name for s in ('upload', 'retain'))
                        else 'artifact_download' if 'download-artifact' in name else 'other')
        result['steps'].append(item)
    return result


def normalize_artifact(raw):
    result = fields(raw, ('id', 'created_at', 'size_in_bytes', 'expired', 'digest'))
    name = raw.get('name', '')
    result['server_source_sha'] = name[7:] if re.fullmatch('server-[0-9a-f]{40}', name) else None
    return result
