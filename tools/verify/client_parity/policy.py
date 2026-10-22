"""The existing feature registry is the single machine-readable parity matrix."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PLATFORMS = {'web', 'ios', 'android'}
STATUSES = {'PARITY', 'GAP', 'PLATFORM_EXCEPTION', 'NOT_VERIFIED', 'PLANNED'}
DECISIONS = {'implementation_and_regression', 'platform_exception', 'linked_gap'}

def validate(catalog, root=ROOT):
    seen = set()
    for feature, item in catalog.items():
        review = item.get('parity_review', {})
        if not isinstance(review.get('issue'), int) or set(review.get('decisions', {})) != PLATFORMS or not set(review['decisions'].values()) <= DECISIONS:
            raise ValueError('Missing platform decision: ' + feature)
        rows = item.get('parity', [])
        if not rows: raise ValueError('Missing parity scenarios: ' + feature)
        for row in rows:
            if not row.get('id') or row['id'] in seen: raise ValueError('Missing or duplicate scenario ID')
            seen.add(row['id'])
            if row.get('status') not in STATUSES or not row.get('expected') or not row.get('source') or not row.get('shipped') or not isinstance(row.get('issue'), int):
                raise ValueError('Incomplete parity scenario: ' + row['id'])
            if row['status'] in {'GAP', 'PLATFORM_EXCEPTION', 'PLANNED'} and (not row.get('reason') or not row.get('tracking_issue')):
                raise ValueError('Unexplained gap or exception: ' + row['id'])
            if set(row.get('platforms', {})) != PLATFORMS: raise ValueError('Missing client: ' + row['id'])
            for platform, value in row['platforms'].items():
                paths = [value.get('entrypoint', ''), *value.get('tests', [])]
                if not value.get('tests') or any(not p or not (root / p).is_file() for p in paths) or not value.get('conditions'):
                    raise ValueError('Missing implementation, conditions or tests: ' + platform + ':' + row['id'])
                if value.get('runtime') not in {'PASS', 'FAIL', 'NOT_RUN', 'NOT_VERIFIED', 'BLOCKED'}: raise ValueError('Invalid evidence state')
                if value['runtime'] == 'PASS' and (not value.get('evidence') or not value.get('build') or not value.get('source_sha')):
                    raise ValueError('Runtime PASS needs separate platform/build/source evidence')
