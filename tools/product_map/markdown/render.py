"""Render browsable, escaped GitHub Markdown from the validated projection."""
import re
from pathlib import PurePosixPath
from urllib.parse import quote

from tools.product_map.projection.importer import PLATFORMS
from tools.product_map.projection.render import cell

ID = re.compile(r'[a-z][a-z0-9_-]*(?:\.[a-z0-9_-]+)*\Z')


def _id(value):
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise ValueError('invalid product feature ID')
    return value


def _state(value):
    current, target = value.get('implemented_revision'), value.get('target_revision')
    def rev(item): return 'r' + str(item) if type(item) is int and item > 0 else '?'
    versions = f' ({rev(current)} → {rev(target)})' if current is not None or target is not None else ''
    return cell(value['source_status'] + versions)


def render_index(features):
    identifiers = [_id(item['id']) for item in features]
    if len(set(identifiers)) != len(identifiers):
        raise ValueError('duplicate product feature ID')
    lines = ['# Карта продукта — предварительная проекция', '',
             'Исходный код, релиз и runtime показаны раздельно. UNKNOWN означает отсутствие подтверждения.', '',
             '[Системная архитектура](architecture.md)', '',
             '| Функция | ' + ' | '.join(PLATFORMS) + ' |',
             '| --- | ' + ' | '.join('---' for _ in PLATFORMS) + ' |']
    for item in sorted(features, key=lambda row: _id(row['id'])):
        identifier = _id(item['id'])
        columns = []
        for name in PLATFORMS:
            data = item['platforms'][name]
            columns.append('<br>'.join((_state(data), cell(data['released']), cell(data['runtime']))))
        lines.append('| [' + cell(identifier) + '](features/' + identifier + '.md)<br>' +
                     cell(item['description']) + ' | ' + ' | '.join(columns) + ' |')
    return '\n'.join(lines) + '\n'


def _path_link(path):
    if not isinstance(path, str) or not path or '\\' in path or ':' in path:
        return cell(path)
    parts = path.split('/')
    if PurePosixPath(path).is_absolute() or any(part in ('', '.', '..') for part in parts):
        return cell(path)
    return '[' + cell(path) + '](../../../../' + quote(path, safe='/') + ')'


def render_feature(item):
    identifier = _id(item['id'])
    lines = ['# ' + cell(item.get('title', identifier)), '',
             'ID: `' + identifier + '`', '', 'Описание: ' + cell(item['description']), '',
             '[← Матрица](../index.md)', '', '## Платформы', '',
             '| Платформа | Исходники | Релиз | Runtime |', '| --- | --- | --- | --- |']
    for name in PLATFORMS:
        data = item['platforms'][name]
        lines.append('| ' + name + ' | ' + _state(data) + ' | ' +
                     cell(data['released']) + ' | ' + cell(data['runtime']) + ' |')
    lines += ['', '## Компоненты', '']
    for component in item.get('components', []):
        paths = ', '.join(_path_link(path) for path in component['paths'])
        lines.append('- ' + cell(component['id']) + ': ' + paths)
    if not item.get('components'):
        lines.append('Пока не описаны.')
    dependencies = item.get('depends_on', [])
    if dependencies:
        lines += ['', '## Зависимости функций', '']
        lines += ['- [' + cell(_id(ref)) + '](' + _id(ref) + '.md)' for ref in dependencies]
    edges = item.get('component_edges', [])
    if edges:
        lines += ['', '## Связи компонентов', '']
        lines += ['- ' + cell(edge['from']) + ' → ' + cell(edge['to']) + ' (зависит от)'
                  for edge in edges]
    return '\n'.join(lines) + '\n'
