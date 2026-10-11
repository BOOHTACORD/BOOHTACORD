import hashlib
import html
import json
import shutil
from pathlib import Path


def verdict(stages, screenshots):
    if not stages: return 'NOT_RUN'
    if any(stage['status'] == 'FAIL' for stage in stages): return 'FAIL'
    if any(stage['status'] == 'BLOCKED' for stage in stages): return 'BLOCKED'
    return 'REVIEW_REQUIRED' if screenshots else 'NOT_RUN_VISUAL'


def write_report(destination, stages, source, features, platforms, images):
    shots = []
    for name, path in images:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        target = destination/'images'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        shots.append({'name': name, 'sha256': digest, 'path': str(target.relative_to(destination))})
    result = {'status': verdict(stages, len(shots)), 'source': source,
              'features': features, 'platforms': platforms, 'stages': stages,
              'screenshots': shots, 'visual_review': 'NOT_RUN',
              'limits': ['Widget captures do not prove device runtime or media quality.',
                         'Review every selected feature; untested device scenarios remain NOT_RUN.']}
    (destination/'report.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    cards = ''.join('<article data-name="'+html.escape(s['name'],quote=True)+'"><h3>'+html.escape(s['name'])+'</h3><a href="'+s['path']+'"><img loading="lazy" src="'+s['path']+'"></a></article>' for s in shots)
    rows = ''.join('<tr><td>'+html.escape(s['name'])+'</td><td>'+s['status']+'</td></tr>' for s in stages)
    (destination/'index.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>BOOHTACORD — локальная проверка</title><style>body{background:#10131c;color:#e5e7f2;font:16px system-ui;max-width:1500px;margin:32px auto;padding:0 24px}h1{font-size:26px}p{overflow-wrap:anywhere}table{border-collapse:collapse}td{padding:8px 20px;border-bottom:1px solid #45475a}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:24px}article{background:#202532;padding:12px;overflow:hidden}img{width:100%;max-height:650px;object-fit:contain}h3{font-size:13px;overflow-wrap:anywhere}a{color:#b4a4ff}</style><h1>Проверка изменений BOOHTACORD</h1>' + '<p>'+html.escape(source)+' · '+result['status']+'</p><p>Откройте снимки и оцените переносы текста, обрезку, контраст, фокус, клавиатуру и состояния ошибок. Автоматический PASS не означает визуальную приёмку.</p><table>'+rows+'</table><h2>Снимки</h2><label>Фильтр по платформе или экрану <input id="filter" type="search" placeholder="android, ios, auth, mobile…"></label><div class="gallery">'+cards+'</div><script>document.getElementById("filter").addEventListener("input",e=>{const q=e.target.value.toLowerCase();document.querySelectorAll("article").forEach(a=>a.hidden=!a.dataset.name.toLowerCase().includes(q))})</script></html>')
    return result
