"""Prepare one lossless synthetic capture archive without changing QA verdicts."""
import json
from pathlib import Path
from . import capture_data as data, capture_inventory as inventory, captures


def destination(root, identity):
    data.identity(identity)
    return Path(root) / ('.out/ci/capture-packages/' + identity['component'] + '-' + identity['profile'])


def profile_report(root, identity, upstream_status):
    part = inventory.part_path(root, identity)
    if not part.exists():
        data.require(upstream_status != 'success')
        return None
    raw, _ = data.payload(part, '.json')
    value = data.strict_json(raw)
    data.require(isinstance(value, dict) and value.get('profile') == identity['profile']
                 and value.get('status') in ('PASS', 'FAIL'))
    if upstream_status == 'success':
        data.require(value['status'] == 'PASS' and value.get('source_revision') == identity['source_revision'])
        execution = value.get('execution', {}) if identity['component'] == 'web' else value
        data.require(all(execution.get(k) == identity[k] for k in ('run_id', 'run_attempt', 'namespace')))
    return value


def finish(root, identity, upstream_status):
    root = Path(root)
    data.require(upstream_status in ('success', 'failure', 'cancelled'))
    inventory.started(root, identity)
    target = destination(root, identity)
    data.require(not target.exists() and not target.is_symlink())
    files, ignored = inventory.collect(root, identity['component'])
    part = profile_report(root, identity, upstream_status)
    if upstream_status == 'success':
        inventory.complete(identity['component'], files)
        if identity['component'] == 'flutter':
            measured = {}
            for name, path in files.items():
                raw, digest = data.payload(path, '.png')
                measured[name] = {'bytes': len(raw), 'sha256': digest}
            data.require(part.get('artifacts') == measured)
    report = {'schema_version': 1, 'kind': 'synthetic-capture-publication',
              'upstream_status': upstream_status,
              'profile_status': part['status'] if part else 'UNAVAILABLE',
              'capture_files': len(files), 'excluded_non_capture_files': ignored}
    public = inventory.marker_path(root, identity).with_name(identity['component'] + '-' + identity['profile'] + '-publication.json')
    data.require(public.resolve() == public and not public.exists() and not public.is_symlink()
                 and 'capture-publication.json' not in files)
    with public.open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(report, sort_keys=True) + '\n')
    try:
        captures.pack({**files, 'capture-publication.json': public}, target, identity)
    except Exception:
        public.unlink()
        raise
    return target
