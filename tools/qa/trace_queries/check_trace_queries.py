"""Check every dashboard query against private stores, without printing private IDs.

Use an existing private tunnel for a deployed store. Reports contain panel IDs,
latency and result counts only, never query values. No data is not healthy zero;
successful query execution is not evidence that no telemetry was lost.
"""
import argparse
import ipaddress
import json
import pathlib
import re
import time
import urllib.error
import urllib.parse
import urllib.request


def panels(items):
    for item in items:
        yield item
        yield from panels(item.get('panels', []))


def targets(dashboard):
    for panel in panels(dashboard['panels']):
        for target in panel.get('targets', []):
            if target.get('queryType') == 'traceql':
                yield panel, target, 'traceql'
            elif target.get('expr'):
                yield panel, target, 'promql'


def private_endpoint(value):
    endpoint = urllib.parse.urlsplit(value)
    try:
        private = endpoint.hostname == 'localhost' or ipaddress.ip_address(endpoint.hostname).is_private
    except ValueError:
        private = False
    if (endpoint.scheme != 'http' or not private or endpoint.username or endpoint.password or
            endpoint.query or endpoint.fragment):
        raise ValueError('private HTTP QA endpoint required; no embedded credentials')
    return value.rstrip('/')


def render_query(query, values):
    def replace(match):
        key = match[1]
        if key not in values:
            raise ValueError('unknown query variable')
        value = values[key]
        if value == '$__all' or value == ['$__all']:
            return '.*'
        strings = value if isinstance(value, list) else [value]
        if not strings:
            raise ValueError('empty multiselect')
        # Escape regex metacharacters, then the enclosing TraceQL JSON string.
        escaped = [re.sub(r'([\\^$.*+?()\[\]{}|])', r'\\\1', str(item)) for item in strings]
        expression = '(' + '|'.join(escaped) + ')' if len(escaped) > 1 else escaped[0]
        # Grafana :regex emits regex escapes (\.) directly. TraceQL raw
        # literals preserve them; JSON strings need a second escaping layer.
        raw_literal = query[:match.start()].count('`') % 2 == 1
        if raw_literal:
            if any('`' in str(item) or '\n' in str(item) or '\r' in str(item) for item in strings):
                raise ValueError('raw TraceQL delimiter in variable')
            return expression
        return json.dumps(expression, ensure_ascii=False)[1:-1]
    rendered = re.sub(r'\$\{([a-z_]+):regex\}', replace, query)
    if '${' in rendered:
        raise ValueError('unexpanded query variable')
    return rendered


def query_request(opener, url, timeout=30):
    with opener.open(url, timeout=timeout) as response:
        return json.load(response)


def check(dashboard, tempo, prometheus=None, values=None, windows=(900, 21600, 86400), now=None):
    values = values or {v['name']: '$__all' for v in dashboard['templating']['list']}
    now = int(time.time()) if now is None else now
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    report = []
    for window in windows:
        for panel, target, kind in targets(dashboard):
            if kind == 'promql' and not prometheus:
                continue
            row = {'panel': panel['id'], 'target': target.get('refId', 'A'), 'kind': kind,
                   'window_seconds': window, 'status': 'FAIL'}
            started = time.monotonic()
            try:
                if kind == 'traceql':
                    query = render_query(target['query'], values)
                    params = {'q': query, 'start': now-window, 'end': now,
                              'limit': min(int(target.get('limit', 500)), 500),
                              'spss': min(int(target.get('spss', 20)), 50)}
                    result = query_request(opener, tempo+'/api/search?'+urllib.parse.urlencode(params))
                    count = len(result.get('traces', []))
                    row.update(traces=count, limit=params['limit'], query_limit_reached=count >= params['limit'])
                else:
                    params = {'query': target['expr'], 'time': now}
                    route = '/api/v1/query'
                    if not target.get('instant'):
                        route = '/api/v1/query_range'
                        params = {'query': target['expr'], 'start': now-window, 'end': now,
                                  'step': max(15, window//500)}
                    result = query_request(opener, prometheus+route+'?'+urllib.parse.urlencode(params))
                    if result.get('status') != 'success':
                        raise ValueError('Prometheus rejected query')
                    row['series'] = len(result.get('data', {}).get('result', []))
                row['status'] = 'PASS'
            except urllib.error.HTTPError as error:
                row['error'] = 'HTTP '+str(error.code)
            except (OSError, ValueError) as error:
                row['error'] = type(error).__name__
            row['latency_ms'] = round((time.monotonic()-started)*1000, 2)
            report.append(row)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tempo_url', type=private_endpoint)
    parser.add_argument('dashboard_json', type=pathlib.Path)
    parser.add_argument('--prometheus-url', type=private_endpoint)
    parser.add_argument('--filters', type=pathlib.Path, help='private JSON exact values; omitted values are All')
    parser.add_argument('--window', type=int, action='append', help='seconds; default 900, 21600, 86400')
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    dashboard = json.loads(args.dashboard_json.read_text(encoding='utf-8'))
    values = {v['name']: '$__all' for v in dashboard['templating']['list']}
    if args.filters:
        values.update(json.loads(args.filters.read_text(encoding='utf-8')))
    report = check(dashboard, args.tempo_url, args.prometheus_url, values, args.window or (900, 21600, 86400))
    if not report:
        raise SystemExit('no queries found')
    for row in report:
        print(json.dumps(row, separators=(',', ':')))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    if any(row['status'] != 'PASS' for row in report):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
