"""Synthetic OTLP → Collector → Prometheus contract probe on an owned private stack."""
import argparse
import ipaddress
import json
import time
import urllib.parse
import urllib.request


def private_origin(value):
    url = urllib.parse.urlsplit(value)
    try:
        private = url.hostname == 'localhost' or ipaddress.ip_address(url.hostname).is_private
    except ValueError:
        private = False
    if (url.scheme != 'http' or not private or url.username or url.password or
            url.path not in ('', '/') or url.query or url.fragment):
        raise ValueError('owned private HTTP origin required')
    return value.rstrip('/')


def verify_series(rows):
    assert rows, 'required stored series unavailable'
    forbidden = {'user_id', 'session_id', 'app_visit_id', 'app_flow_id',
                 'app_media_session_id', 'trace_id', 'request_id', 'scope_identity',
                 'user.id', 'session.id', 'app.visit.id', 'app.flow.id',
                 'app.media.session.id', 'trace.id', 'request.id'}
    for row in rows:
        assert not forbidden.intersection(row['metric']), 'private identity became a metric label'


def run(collector, prometheus):
    collector, prometheus = private_origin(collector), private_origin(prometheus)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    now = str(time.time_ns())
    attributes = [{'key': 'service.name', 'value': {'stringValue': 'boohtacord-qa-delivery'}},
                  {'key': 'service.version', 'value': {'stringValue': 'issue513'}}]
    for key in ('user.id', 'session.id', 'app.visit.id', 'app.flow.id', 'app.media.session.id', 'trace.id'):
        attributes.append({'key': key, 'value': {'stringValue': 'synthetic-resource-not-a-label'}})
    body = {'resourceMetrics': [{'resource': {'attributes': attributes}, 'scopeMetrics': [{
        'scope': {'name': 'qa.delivery'}, 'metrics': [
            {'name': 'boohtacord.qa.delivery.requests', 'sum': {'aggregationTemporality': 2, 'isMonotonic': True,
             'dataPoints': [{'timeUnixNano': now, 'startTimeUnixNano': now, 'asInt': '2'}]}},
            {'name': 'boohtacord.qa.delivery.latency', 'unit': 's', 'histogram': {'aggregationTemporality': 2,
             'dataPoints': [{'timeUnixNano': now, 'startTimeUnixNano': now, 'count': '2', 'sum': .25,
                            'explicitBounds': [.1, .5], 'bucketCounts': ['1', '1', '0']}]}}
        ]}]}]}
    request = urllib.request.Request(collector + '/v1/metrics', data=json.dumps(body).encode(),
                                     headers={'Content-Type': 'application/json'})
    with opener.open(request, timeout=5) as response:
        assert response.status == 200, 'Collector did not accept synthetic metrics'
    query = '{__name__=~"boohtacord_qa_delivery_.*"}'
    url = prometheus + '/api/v1/query?' + urllib.parse.urlencode({'query': query})
    deadline = time.monotonic() + 35
    while True:
        with opener.open(url, timeout=5) as response:
            payload = json.load(response)
        assert payload['status'] == 'success', 'Prometheus query failed'
        rows = payload['data']['result']
        if rows:
            break
        if time.monotonic() >= deadline:
            raise AssertionError('accepted metrics were not queryable before deadline')
        time.sleep(.5)
    verify_series(rows)
    values = {(r['metric']['__name__'], r['metric'].get('le')): float(r['value'][1]) for r in rows}
    assert values[('boohtacord_qa_delivery_requests_total', None)] == 2
    assert values[('boohtacord_qa_delivery_latency_seconds_sum', None)] == .25
    assert values[('boohtacord_qa_delivery_latency_seconds_count', None)] == 2
    buckets = {float(bound): value for (name, bound), value in values.items()
               if name == 'boohtacord_qa_delivery_latency_seconds_bucket'}
    assert buckets[.1] == 1
    assert buckets[.5] == 2
    target_query = urllib.parse.urlencode({'query': 'target_info{job="boohtacord-otel-metrics"}'})
    with opener.open(prometheus + '/api/v1/query?' + target_query, timeout=5) as response:
        assert not json.load(response)['data']['result'], 'arbitrary resource target_info stored'
    return {'status': 'PASS', 'required_series': len(rows), 'unit': 'seconds',
            'histogram_and_counter': 'PASS', 'resource_label_privacy': 'PASS'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('collector')
    parser.add_argument('prometheus')
    args = parser.parse_args()
    print(json.dumps(run(args.collector, args.prometheus)))


if __name__ == '__main__':
    main()
