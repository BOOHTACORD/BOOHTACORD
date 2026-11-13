"""Deterministic, self-contained projection viewer with no network access."""
import base64
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _hash(value):
    return base64.b64encode(hashlib.sha256(value.encode('utf-8')).digest()).decode('ascii')


def build_document(features, system_topology=None):
    payload = json.dumps(features, ensure_ascii=True, sort_keys=True, separators=(',', ':'))
    payload = payload.replace('<', r'\u003c').replace('>', r'\u003e').replace('&', r'\u0026')
    topology = json.dumps(system_topology or {'nodes': [], 'edges': []}, ensure_ascii=True,
                          sort_keys=True, separators=(',', ':'))
    topology = topology.replace('<', r'\u003c').replace('>', r'\u003e').replace('&', r'\u0026')
    script = 'const data = ' + payload + ';\nconst systemTopology = ' + topology + ';\n' + '\n'.join(
        (HERE / name).read_text(encoding='utf-8') for name in ('filters.js', 'detail.js', 'system_graph.js', 'app.js'))
    script += "\nrenderSystemGraph(systemTopology, document.getElementById('system-graph'), document.getElementById('system-links'), document.getElementById('system-edges'));"
    style = (HERE / 'style.css').read_text(encoding='utf-8')
    csp = f"default-src 'none'; style-src 'sha256-{_hash(style)}'; script-src 'sha256-{_hash(script)}'; base-uri 'none'; form-action 'none'"
    return f'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="{csp}"><title>Карта BOOHTACORD</title><style>{style}</style></head>
<body><main><h1>Карта BOOHTACORD: предварительная проекция</h1>
<p>Данные получены из каталога и parity-реестра. UNKNOWN не означает отсутствие функции; релизы и runtime не подтверждаются кодом.</p>
<label for="search">Поиск по ID или сценарию</label> <input id="search" type="search">
<div class="filters"><label for="platform">Платформа</label> <select id="platform"><option value="all">Все</option><option value="web">Web</option><option value="windows">Windows</option><option value="macos">macOS</option><option value="android">Android</option><option value="ios">iOS</option></select>
<label for="domain">Область</label> <select id="domain"><option value="all">Все</option></select>
<label for="status">Фильтр состояния</label> <select id="status"><option value="all">Все</option><option value="differences">Расхождения исходников</option><option value="behind">Отстающие исходники</option><option value="unverified">Не подтверждено</option><option value="exceptions">Исключения</option></select>
<fieldset><legend>Слои</legend><label><input id="layer-source" type="checkbox" checked> Исходники</label> <label><input id="layer-release" type="checkbox" checked> Релиз</label> <label><input id="layer-runtime" type="checkbox" checked> Runtime</label></fieldset></div>
<p id="count" aria-live="polite"></p><div class="table-wrap"><table id="matrix"><thead><tr id="header"><th scope="col">Сценарий</th>
<th scope="col">Web</th><th scope="col">Windows</th><th scope="col">macOS</th><th scope="col">Android</th><th scope="col">iOS</th></tr></thead><tbody id="rows"></tbody></table></div>
<section aria-labelledby="detail-heading"><h2 id="detail-heading">Компоненты сценария</h2><div id="detail" aria-live="polite">Выберите ID в таблице.</div></section>
<section aria-labelledby="system-heading"><h2 id="system-heading">Системная архитектура</h2>
<p>Частичная схема исходников. Ссылка на тест не подтверждает его прохождение, публикацию или работу в среде.</p>
<p>Схему можно прокручивать по горизонтали; все её связи перечислены ниже текстом.</p>
<div class="system-graph-scroll" role="region" aria-label="Схема компонентов" tabindex="0"><svg id="system-graph" viewBox="0 0 1200 720" role="img" aria-labelledby="system-heading"></svg></div>
<h3>Компоненты и исходники</h3><ul id="system-links"></ul><h3>Связи</h3><ul id="system-edges"></ul></section>
<noscript>Доступна <a href="index.md">карта в Markdown</a>; для интерактивной таблицы включите JavaScript.</noscript></main><script>{script}</script></body></html>'''


def write_document(path, content, *, check):
    if check:
        return path.is_file() and path.read_text(encoding='utf-8') == content
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8', newline='\n')
    return True
