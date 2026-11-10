"""Deterministic, self-contained projection viewer with no network access."""
import base64
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _hash(value):
    return base64.b64encode(hashlib.sha256(value.encode('utf-8')).digest()).decode('ascii')


def build_document(features):
    payload = json.dumps(features, ensure_ascii=True, sort_keys=True, separators=(',', ':'))
    payload = payload.replace('<', r'\u003c').replace('>', r'\u003e').replace('&', r'\u0026')
    script = 'const data = ' + payload + ';\n' + (HERE / 'app.js').read_text(encoding='utf-8')
    style = (HERE / 'style.css').read_text(encoding='utf-8')
    csp = f"default-src 'none'; style-src 'sha256-{_hash(style)}'; script-src 'sha256-{_hash(script)}'; base-uri 'none'; form-action 'none'"
    return f'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="{csp}"><title>Карта BOOHTACORD</title><style>{style}</style></head>
<body><main><h1>Карта BOOHTACORD: предварительная проекция</h1>
<p>Данные получены из parity-реестра. UNKNOWN не означает отсутствие функции; релизы и runtime не подтверждаются кодом.</p>
<label for="search">Поиск по ID или сценарию</label> <input id="search" type="search">
<p id="count" aria-live="polite"></p><div class="table-wrap"><table><thead><tr><th scope="col">Сценарий</th>
<th scope="col">Web</th><th scope="col">Windows</th><th scope="col">macOS</th><th scope="col">Android</th><th scope="col">iOS</th></tr></thead><tbody id="rows"></tbody></table></div>
<noscript>Для интерактивной таблицы включите JavaScript. Доступна команда python -m tools.product_map matrix.</noscript></main><script>{script}</script></body></html>'''


def write_document(path, content, *, check):
    if check:
        return path.is_file() and path.read_text(encoding='utf-8') == content
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8', newline='\n')
    return True
