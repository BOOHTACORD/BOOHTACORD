"""Render the partial system topology as safe, browsable Markdown."""
from pathlib import PurePosixPath
from urllib.parse import quote

from tools.product_map.projection.render import cell


def _source(path):
    if (not isinstance(path, str) or not path or '\\' in path or ':' in path or
            PurePosixPath(path).is_absolute() or any(part in ('', '.', '..') for part in path.split('/')) or
            any(ord(char) < 32 or ord(char) == 127 for char in path)):
        raise ValueError('unsafe source path')
    return '../../../' + quote(path, safe='/')


def render_architecture(graph):
    lines = ['# Системная архитектура — частичная схема исходников', '',
             'Ссылки отражают исходники в этой ветке. Тестовый файл не подтверждает PASS, релиз или runtime.', '',
             '[Матрица функций](index.md)', '', '## Компоненты', '',
             '| ID | Компонент | Исходник |', '| --- | --- | --- |']
    for node in graph['nodes']:
        lines.append('| ' + cell(node['id']) + ' | ' + cell(node['label']) + ' | [' +
                     cell(node['path']) + '](' + _source(node['path']) + ') |')
    lines += ['', '## Направленные связи', '']
    for edge in graph['edges']:
        lines.append('- ' + cell(edge['from']) + ' → ' + cell(edge['to']) + ' (' + cell(edge['type']) + ')')
    return '\n'.join(lines) + '\n'


def write_architecture(path, graph, *, check):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError('generated Markdown file or directory is a symlink')
    content = render_architecture(graph)
    if check:
        return path.is_file() and path.read_text(encoding='utf-8') == content
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8', newline='\n')
    return True
