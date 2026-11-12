"""Validate a source-linked, non-status system topology."""
import re
from pathlib import PurePosixPath

NODE = re.compile(r'sys(?:\.[a-z0-9_-]+)+\Z')
KINDS = {'product_feature', 'client_component', 'shared_component', 'platform_adapter',
         'backend_component', 'infrastructure', 'contract', 'test_evidence'}
EDGES = {'runs', 'routes', 'calls', 'depends_on', 'media', 'implements',
         'shared_by', 'verified_by', 'emits', 'consumes'}


def validate_graph(graph, root):
    if (not isinstance(graph, dict) or set(graph) != {'nodes', 'edges'} or
            not isinstance(graph['nodes'], list) or not graph['nodes'] or
            not isinstance(graph['edges'], list)):
        raise ValueError('invalid system graph')
    ids, positions = set(), set()
    for item in graph['nodes']:
        if not isinstance(item, dict) or set(item) != {'id', 'label', 'kind', 'path', 'x', 'y'}:
            raise ValueError('invalid system node')
        identifier, path = item['id'], item['path']
        if not isinstance(identifier, str) or not NODE.fullmatch(identifier) or identifier in ids:
            raise ValueError('invalid or duplicate system node ID')
        if (not isinstance(item['label'], str) or not item['label'].strip() or len(item['label']) > 70 or
                not isinstance(item['kind'], str) or item['kind'] not in KINDS):
            raise ValueError('invalid system node label or kind')
        if (not isinstance(path, str) or not path or '\\' in path or ':' in path or
                any(ord(char) < 32 or ord(char) == 127 for char in path) or
                PurePosixPath(path).is_absolute() or any(part in ('', '.', '..') for part in path.split('/'))):
            raise ValueError('unsafe system node path')
        target = root.joinpath(*PurePosixPath(path).parts).resolve()
        if not target.is_relative_to(root.resolve()) or not target.is_file():
            raise ValueError('missing or external system node path')
        if (type(item['x']) is not int or type(item['y']) is not int or
                not 0 <= item['x'] <= 1020 or not 0 <= item['y'] <= 664 or
                (item['x'], item['y']) in positions):
            raise ValueError('invalid system node position')
        ids.add(identifier)
        positions.add((item['x'], item['y']))
    seen = set()
    for edge in graph['edges']:
        if (not isinstance(edge, dict) or set(edge) != {'from', 'to', 'type'} or
                not all(isinstance(edge[key], str) for key in ('from', 'to', 'type')) or
                edge['from'] not in ids or edge['to'] not in ids or
                edge['from'] == edge['to'] or edge['type'] not in EDGES):
            raise ValueError('invalid system edge')
        key = (edge['from'], edge['to'], edge['type'])
        if key in seen:
            raise ValueError('duplicate system edge')
        seen.add(key)
