"""Fixed backend worker/stage/event names and the normalized HTTP template."""
import re

from .scenarios import scenario


def inventory(root, producer, consumers, delivery):
    result = []
    for path in sorted((root / 'backend/internal').rglob('*.go')):
        if path.name.endswith('_test.go'):
            continue
        source = path.read_text(encoding='utf-8')
        found = [(m.group(1), m.start(), 'span') for m in re.finditer(r'(?:\.Start|\.start|flowstage\.Begin)\([^,\n]+,\s*"([^"]+)"', source)]
        found += [(m.group(1), m.start(), 'event') for m in re.finditer(r'\.AddEvent\(\s*"([^"]+)"', source)]
        if path.as_posix().endswith('/guild_lifecycle/finish.go'):
            found += [(m.group(1), m.start(), 'event') for m in re.finditer(r'"(app\.registration\.welcome\.[^"]+)"', source)]
        for name, pos, kind in found:
            attrs = sorted(set(re.findall(r'attribute\.(?:String|Int|Float64|Bool)\(\s*"([^"]+)"', source)))
            result.append({'scenario': scenario(name, path.as_posix()), 'producer': [producer(path, source.count('\n', 0, pos) + 1)],
                'source_name': name, 'exported_name': name, 'type': 'span/event', 'unit': 'duration/timestamp ns',
                'record_kind': kind, 'attributes_or_labels': attrs,
                'attribute_scope': 'Literal attribute keys in producer; flow/session metadata may additionally come from shared binding helpers. No metric labels.',
                'frequency': 'per actual stage/attempt/state transition; no event per frame or regular heartbeat',
                'storage': 'private Tempo', 'consumers': consumers(name, 'span/event'),
                'decision': 'add' if name.startswith(('app.screen.viewer.', 'app.screen.audience.')) else 'keep',
                'reason': 'Keep actual transition/worker outcome and causal links separate from polling and HTTP acknowledgement.',
                'delivery': {**delivery('OTLP-trace'), 'boundary': 'Server OTel -> bounded exporter -> Collector -> private Tempo'}})
    path = root / 'backend/internal/observability/trace_http/middleware.go'
    result.append({'scenario': 'telemetry', 'producer': [producer(path)],
        'source_name': 'HTTP normalized request', 'exported_name': '${SAFE_METHOD} ${SERVEMUX_ROUTE_TEMPLATE}',
        'name_kind': 'registered normalized template; unmatched collapsed', 'type': 'span/event',
        'unit': 'duration ns', 'attributes_or_labels': ['http.request.method', 'http.route', 'http.response.status_code', 'request_id', 'user.id', 'session.id'],
        'frequency': 'sampled request completion, except explicitly operational paths; presence success suppression is outcome-aware',
        'storage': 'private Tempo', 'consumers': consumers('http.route', 'span/event'), 'decision': 'change',
        'reason': 'Successful routine presence spans suppressed independently of complete HTTP metrics; errors, meaningful transitions and flow-bound calls retained.',
        'delivery': {**delivery('OTLP-trace'), 'boundary': 'Server OTel -> bounded exporter -> Collector -> private Tempo'}})
    return result
