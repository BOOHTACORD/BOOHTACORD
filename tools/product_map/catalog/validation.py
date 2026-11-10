"""Validate curated product relationships without assigning runtime status."""
import re
from pathlib import PurePosixPath

from tools.product_map.projection.importer import PLATFORMS
from .graph import validate_dependencies

FEATURE = re.compile(r'[a-z][a-z0-9_-]*(?:\.[a-z0-9_-]+)*\Z')
COMPONENT = re.compile(r'cmp(?:\.[a-z0-9_-]+)+\Z')
APPLICABILITY = {'SUPPORTED', 'NOT_APPLICABLE', 'PLATFORM_EXCEPTION', 'PLANNED', 'UNKNOWN'}
STATES = {'NOT_STARTED', 'PARTIAL', 'IMPLEMENTED', 'UNKNOWN'}


def _positive(value):
    return type(value) is int and value > 0


def _path(root, value):
    path = PurePosixPath(value)
    if (not value or path.is_absolute() or '..' in path.parts or
            '\\' in value or ':' in value):
        raise ValueError(f'unsafe component path: {value}')
    candidate = root.joinpath(*path.parts).resolve()
    if not candidate.is_relative_to(root.resolve()) or not candidate.is_file():
        raise ValueError(f'missing or external component path: {value}')


def validate_catalog(catalog, root, parity_ids):
    components, features = catalog['components'], catalog['features']
    component_ids = set()
    for item in components:
        identifier = item['id']
        if not COMPONENT.fullmatch(identifier) or identifier in component_ids:
            raise ValueError(f'invalid or duplicate component ID: {identifier}')
        component_ids.add(identifier)
        if not item['paths']:
            raise ValueError(f'component without path: {identifier}')
        for path in item['paths']:
            _path(root, path)
    ids = set()
    for item in features:
        identifier = item['id']
        if not FEATURE.fullmatch(identifier) or identifier in ids:
            raise ValueError(f'invalid or duplicate feature ID: {identifier}')
        ids.add(identifier)
    aliases, covered = set(), set()
    for item in features:
        for alias in item.get('aliases', []):
            if not FEATURE.fullmatch(alias) or alias in aliases or alias in ids:
                raise ValueError(f'invalid or ambiguous alias: {alias}')
            aliases.add(alias)
        refs = set(item['components'])
        if not refs or not refs <= component_ids:
            raise ValueError(f'missing component for {item["id"]}')
        parity = set(item['parity_ids'])
        if not parity <= parity_ids:
            raise ValueError(f'unknown parity ID for {item["id"]}')
        covered |= parity
        _validate_feature(item)
    if covered != parity_ids:
        raise ValueError('existing parity IDs are not fully mapped')
    validate_dependencies(features)


def _validate_feature(item):
    target = item['target_revision']
    revisions = item['behavior_revisions']
    valid_unknown = target is None and revisions == []
    valid_known = (_positive(target) and bool(revisions) and
                   [r['revision'] for r in revisions] == list(range(1, target + 1)) and
                   all(r['summary'].strip() for r in revisions))
    if not (valid_unknown or valid_known):
        raise ValueError(f'invalid behavior revision history: {item["id"]}')
    if set(item['platforms']) != set(PLATFORMS):
        raise ValueError(f'missing platform for {item["id"]}')
    for platform, value in item['platforms'].items():
        if value['applicability'] not in APPLICABILITY or value['state'] not in STATES:
            raise ValueError(f'invalid platform state: {platform}')
        revision = value['revision']
        if revision is not None and not _positive(revision):
            raise ValueError(f'invalid implementation revision: {platform}')
        if value['state'] == 'IMPLEMENTED' and revision is None:
            raise ValueError(f'missing implementation revision: {platform}')
        if value['applicability'] in {'NOT_APPLICABLE', 'PLATFORM_EXCEPTION'}:
            fields = ('reason', 'owner', 'alternative', 'review_date')
            complete = all(isinstance(value.get(k), str) and value[k].strip()
                           for k in fields)
            if not complete or not _positive(value.get('tracking_issue')):
                raise ValueError(f'unexplained platform exception: {platform}')
