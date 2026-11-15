"""Retain original Cargo dependency notices, rejecting unresolved licenses."""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
AUDITED = {'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'CC0-1.0',
           '0BSD', 'Unlicense', 'Zlib', 'Unicode-DFS-2016', 'Unicode-3.0',
           'BlueOak-1.0.0', 'OR', 'AND'}


def collect(metadata, output):
    if output.exists():
        raise ValueError('Notice destination already exists')
    fallbacks = {row['package']: row for row in
                 json.loads((HERE / 'upstream.json').read_text(encoding='utf-8-sig'))}
    included = {node['id'] for node in metadata['resolve']['nodes']}
    artifacts, entries = {}, []
    for package in metadata['packages']:
        if package['id'] not in included:
            continue
        license = package.get('license') or ''
        if not license or set(re.findall(r'[A-Za-z0-9.-]+', license)) - AUDITED:
            raise ValueError('Unaudited license: ' + package['name'])
        name = package['name'] + '-' + package['version']
        if not re.fullmatch(r'[A-Za-z0-9_.+-]+', name):
            raise ValueError('Unsafe package identity')
        root = Path(package['manifest_path']).resolve().parent
        candidates = [p for p in root.iterdir() if p.is_file() and
                      re.search(r'licen[cs]e|copying|copyright|notice', p.name, re.I)]
        for directory in ('LICENSES', 'licenses'):
            if (root / directory).is_dir():
                candidates.extend(p for p in (root / directory).rglob('*') if p.is_file())
        notices = {}
        for file in candidates:
            if not file.resolve().is_relative_to(root.parent):
                raise ValueError('Unsafe license link')
            notices[file.relative_to(root).as_posix()] = file.read_bytes()
        if not notices:
            fallback = fallbacks.get(name)
            if fallback is None or 'MIT' not in re.findall(r'[A-Za-z0-9.-]+', license):
                raise ValueError('Missing original notice: ' + name)
            text = (HERE / 'upstream' / fallback['file']).read_bytes().replace(b'\r\n', b'\n')
            if hashlib.sha256(text).hexdigest() != fallback['sha256']:
                raise ValueError('Pinned upstream notice checksum mismatch')
            notices['LICENSE-MIT.upstream.txt'] = text
        entries.append({'package': name, 'license': license, 'authors': package['authors'],
                        'noticeSource': fallbacks[name]['url'] if not candidates else 'crate source',
                        'notices': {key: hashlib.sha256(data).hexdigest() for key, data in notices.items()}})
        artifacts[name + '/Cargo.toml'] = Path(package['manifest_path']).read_bytes()
        for file, data in notices.items():
            artifacts[name + '/' + file] = data
    output.mkdir(parents=True, exist_ok=False)
    for file, data in artifacts.items():
        path = output / file
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    report = {'packages': len(entries), 'noticeFiles': sum(len(e['notices']) for e in entries),
              'unresolved': [], 'entries': entries}
    (output / 'index.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report
