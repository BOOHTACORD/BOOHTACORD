"""Rebuild the source-bound catalog; storage proof lives in separate evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from .extract import expand, instruments, prometheus_name, native_unit
from .scenarios import SCENARIOS, scenario
from .labels import otel_labels
from .backend_spans import inventory as backend_spans

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/observability/signal-catalog.json'


def producer(path, line=1):
    return {'path': path.relative_to(ROOT).as_posix(), 'line': line,
            'sha256': hashlib.sha256(path.read_text(encoding='utf-8').encode('utf-8')).hexdigest()}


def panels(items):
    for panel in items:
        yield panel
        yield from panels(panel.get('panels', []))


def consumers(name, kind, flow=False):
    found = []
    for path in sorted((ROOT / 'docker/observability/dashboards').glob('*.json')):
        doc = json.loads(path.read_text(encoding='utf-8'))
        for panel in panels(doc.get('panels', [])):
            text = json.dumps(panel.get('targets', []))
            if re.search(re.escape(name) + r'(?:_(?:bucket|sum|count))?(?![a-zA-Z0-9_])', text) or (
                flow and kind == 'span/event' and 'span.app.flow.' in text and panel.get('id') in (41, 42, 43, 44)):
                found.append({'path': path.relative_to(ROOT).as_posix(), 'dashboard_uid': doc['uid'], 'panel': panel['id']})
    for path in sorted((ROOT / 'docker/observability').glob('*alerts.yaml')):
        if name in path.read_text(encoding='utf-8'):
            found.append({'path': path.relative_to(ROOT).as_posix(), 'kind': 'alert-rule'})
    return found


def metric_labels(item, path):
    if item['transport'] != 'OTLP':
        return item['labels'], 'declared constructor labels'
    return otel_labels(item['source_name']), 'bounded per-instrument Add/Record/Observe keys; conditional applicability documented inline'


def delivery(transport):
    return {'transport': transport, 'runtime_status': 'NOT_RUN',
            'boundary': ('private API registry /metrics only; not automatically delivered to Collector' if transport == 'private-prometheus'
                         else 'API OTLP -> Collector -> Prometheus exporter -> private Prometheus; client spans additionally pass authenticated sanitizing relay'),
            'proof': 'Source contract only. Final-SHA evidence must name stored series/trace, versions, source and result independently.'}


def metric_inventory():
    result = []
    for path in sorted((ROOT / 'backend').rglob('*.go')):
        if path.name.endswith('_test.go'):
            continue
        source = path.read_text(encoding='utf-8')
        for raw in instruments(source):
            for item in expand(raw, source):
                labels, label_scope = metric_labels(item, path)
                name = item['source_name']
                if item['type'] == 'CustomCollector':
                    # ConstMetric value kinds reviewed in pool/rate-limit/storage/SFU collectors.
                    item['type'] = 'Counter' if name.endswith('_total') else 'Gauge'
                exported = name if item['transport'] == 'private-prometheus' else prometheus_name(name, item['type'], item['unit'])
                result.append({'scenario': scenario(name, path.as_posix()), 'producer': [producer(path, item['line'])],
                    'source_name': name, 'exported_name': exported, 'type': item['type'],
                    'unit': item['unit'] if item['unit'] != '1' else native_unit(name),
                    'declared_unit': item['unit'],
                    'unit_scope': 'Declared SDK unit, or physical suffix semantics when SDK declares dimensionless; translator uses declared unit.',
                    'attributes_or_labels': labels, 'label_scope': label_scope,
                    'buckets': item['buckets'], 'frequency': 'per bounded operation/sample; observable collection every15s or private scrape on demand',
                    'storage': 'private Prometheus when the declared delivery target is configured',
                    'consumers': consumers(exported, item['type']), 'decision': 'keep',
                    'reason': 'Existing bounded operational distribution/state; native and mirrored names are distinct delivery contracts and must not be added together.',
                    'delivery': delivery(item['transport'])})
    unique = {(r['producer'][0]['path'], r['source_name'], r['delivery']['transport']): r for r in result}
    return list(unique.values())


def span_inventory():
    contract_path = ROOT / 'contracts/telemetry-flow-v1.json'
    contract = json.loads(contract_path.read_text(encoding='utf-8'))
    sources = []
    for base, ext in (('clients/web/src', '*.ts'), ('clients/flutter/lib', '*.dart')):
        sources.extend(p for p in (ROOT / base).rglob(ext) if '.spec.' not in p.name and p.name != 'generated.dart' and p.name != 'generated.ts')
    result = []
    for name in contract['operations']:
        owners = [p for p in sorted(sources, key=lambda value: value.as_posix()) if re.search(r"['\"]" + re.escape(name) + r"['\"]", p.read_text(encoding='utf-8'))]
        if not owners:
            # Allowlisting is not evidence that an operation is emitted.
            continue
        result.append({'scenario': scenario(name), 'producer': [producer(p) for p in owners],
            'source_name': name, 'exported_name': name, 'type': 'span/event', 'unit': 'span duration in ns; attribute units in flow contract',
            'attributes_or_labels': ['session.id', 'app.visit.id', 'app.flow.id', 'app.flow.name', 'app.flow.attempt', 'app.flow.record', 'app.flow.stage', 'app.flow.outcome', 'app.flow.reason', 'app.provenance', 'app.client.version', 'app.media.session.id'],
            'attribute_scope': 'Flow core when applicable. Legacy and media operation profiles use the bounded contract and referenced producer; optional fields are not guaranteed.',
            'attribute_contract': 'contracts/telemetry-flow-v1.json#fields',
            'frequency': ('bounded sample/checkpoint; not a user action' if name in ('media.sample', 'voice.audio.sample', 'telemetry.export.health') else 'per logical action/attempt or bounded legacy phase'),
            'storage': 'private Tempo', 'consumers': consumers(name, 'span/event', name in contract['fields']['app.flow.name']['values']),
            'decision': 'change' if name == 'api.request' else 'keep',
            'reason': 'Successful unscoped presence/auth-session polling is omitted; errors, DELETE and action-bound requests remain.' if name == 'api.request' else 'Keep existing flow/legacy compatibility; allowlisting and source references do not prove live storage.',
            'delivery': {**delivery('client-relay'), 'boundary': 'Client SDK -> authenticated session/origin/generation-bound relay sanitization -> Collector -> private Tempo'}})
    path = ROOT / 'backend/internal/observability/trace_http/application_events.go'
    for route, event in re.findall(r'"((?:GET|POST|PUT|PATCH|DELETE) /[^"]+)":\s*"([^"]+)"', path.read_text(encoding='utf-8')):
        result.append({'scenario': scenario(event + ' ' + route), 'producer': [producer(path)],
            'source_name': event, 'exported_name': [event, event + '.rejected', event + '.failed'],
            'type': 'span/event', 'unit': 'event timestamp ns', 'attributes_or_labels': ['fixed event name; no event body', 'http.route', 'http.request.method', 'http.response.status_code'],
            'frequency': 'once on mapped HTTP completion (2xx /4xx /5xx), including idempotent acceptance',
            'route': route, 'storage': 'private Tempo', 'consumers': consumers(event, 'span/event'),
            'decision': 'keep', 'reason': 'Normalized business acceptance/outcome without raw URL, message/search text or recipient fan-out.',
            'delivery': {**delivery('OTLP-trace'), 'boundary': 'Server HTTP span -> bounded OTel exporter -> Collector -> private Tempo'}})
    return result


def build():
    signals = metric_inventory() + span_inventory() + backend_spans(ROOT, producer, consumers, delivery)
    return {'schema_version': 1, 'issue': 513,
        'generate': 'python -m tools.observability.signal_catalog.build',
        'boundaries': {'runtime_evidence': 'NOT_RUN in this source inventory; final commit and deployed contract are bound by evidence/observability/issue513-*.json, not a self-referential hash.',
            'sampled_tables_are_not_counters': True,
            'source_fingerprint': 'SHA-256 of UTF-8 text with universal newlines normalized to LF; independent of CRLF checkout and locale. Producer paths and owner lists use deterministic POSIX ordering.',
            'metric_names': 'OTLP names are the pinned Collector Prometheus translation contract; compare actual stored families in runtime evidence. Histogram suffixes are _bucket/_sum/_count.',
            'metrics_identity': 'No user/session/visit/flow/media/trace/request/track IDs, raw URLs or error text in metric labels. Resource label allowlist is separately configured in Collector.',
            'duplicate_sources': 'Private collectors are not OTLP automatically. Do not sum a native series and its mirror or conflate independent installations/replicas.',
            'missing_data': 'Missing/stale/unavailable is never healthy zero. A successful relay response is not stored/queryable Tempo proof.'},
        'scenarios': [{'id': key, 'scenario': title, 'coverage_and_limits': note,
                       'signals': sorted(set(s['source_name'] for s in signals if s['scenario'] == key))}
                      for key, title, note in SCENARIOS],
        'signals': sorted(signals, key=lambda s: (s['type'], s['source_name'], s['producer'][0]['path']))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    document = build()
    if args.check:
        if not OUT.exists() or json.loads(OUT.read_text(encoding='utf-8')) != document:
            raise SystemExit('signal catalog differs from source; regenerate and review')
    else:
        with OUT.open('w', encoding='utf-8', newline='\n') as output:
            output.write(json.dumps(document, indent=2, ensure_ascii=False) + '\n')
    print('signals=' + str(len(document['signals'])) + '; source inventory only; runtime verification is separate')


if __name__ == '__main__':
    main()
