"""Render a conservative Markdown matrix from the imported registry."""
from html import escape
import re

from .importer import PLATFORMS


def cell(value):
    text = escape(str(value), quote=True).replace('|', '&#124;').replace('\n', ' ')
    return re.sub(r'([\\`*_\[\]()!])', r'\\\1', text)


def render_matrix(features):
    lines = ['# Матрица платформ — предварительная проекция', '',
             'В ячейке: исходный код / релиз / runtime.',
             'Нет подтверждения релизов и ревизий: UNKNOWN не означает отсутствие.', '',
             '| ID / сценарий | ' + ' | '.join(PLATFORMS) + ' |',
             '| --- | ' + ' | '.join('---' for _ in PLATFORMS) + ' |']
    for feature in features:
        label = cell(feature['id']) + '<br>' + cell(feature['description'])
        columns = []
        for name in PLATFORMS:
            data = feature['platforms'][name]
            columns.append('<br>'.join(cell(data[key]) for key in
                                      ('source_status', 'released', 'runtime')))
        lines.append('| ' + label + ' | ' + ' | '.join(columns) + ' |')
    return '\n'.join(lines) + '\n'
