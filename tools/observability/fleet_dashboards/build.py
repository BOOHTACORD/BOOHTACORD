"""Build scoped views; the existing dashboards remain explicitly legacy/local."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docker/observability/fleet/dashboards'
PROM = {'type': 'prometheus', 'uid': 'boohtacord_prometheus'}
TEMPO = {'type': 'tempo', 'uid': 't-${installation}'}


def installation():
    return {'name': 'installation', 'label': 'Installation', 'type': 'query', 'datasource': PROM,
            'query': 'label_values(boohtacord_installation_registered, installation_id)',
            'refresh': 1, 'multi': False, 'includeAll': False}


def dashboard(name, title, expressions):
    panels = []
    for index, (label, expr) in enumerate(expressions):
        panels.append({'id': index + 1, 'title': label, 'type': 'timeseries', 'datasource': PROM,
                       'gridPos': {'x': index % 2 * 12, 'y': index // 2 * 8, 'w': 12, 'h': 8},
                       'targets': [{'refId': 'A', 'expr': expr}],
                       'links': [{'title': 'Installation traces', 'url': '/d/boohtacord-fleet-traces?var-installation=${installation}'}]})
    return {'uid': 'boohtacord-fleet-' + name, 'title': title, 'schemaVersion': 39, 'version': 1,
            'tags': ['boohtacord', 'installation-scoped'], 'refresh': '15s',
            'templating': {'list': [installation()]}, 'panels': panels,
            'description': 'Registered opt-in installations only. Legacy/local history remains in the original dashboards; it is never attributed to an installation.'}


def build():
    scope = '{installation_id="$installation"}'
    docs = {
        'runtime': dashboard('runtime', 'Installation · Runtime', [
            ('Requests', 'sum by (installation_id) (rate(boohtacord_http_server_requests_total' + scope + '[5m]))'),
            ('HTTP latency', 'histogram_quantile(0.95, sum by (installation_id, le) (rate(boohtacord_http_server_duration_seconds_bucket' + scope + '[5m])))'),
            ('Voice participants', 'sum by (installation_id) (livekit_participant_total' + scope + ')')]),
        'incidents': dashboard('incidents', 'Installation · Incidents', [
            ('HTTP errors', 'sum by (installation_id) (rate(boohtacord_http_server_requests_total{installation_id="$installation",status=~"5.."}[5m]))'),
            ('Last accepted telemetry age', 'time() - boohtacord_installation_last_seen_seconds' + scope),
            ('Registration enabled', 'boohtacord_installation_enabled' + scope)]),
        'media-qoe': dashboard('media-qoe', 'Installation · Media QoE', [
            ('Observed frame cadence', 'histogram_quantile(0.50, sum by (installation_id, le, direction) (rate(boohtacord_media_fps_bucket' + scope + '[5m])))'),
            ('Observed bitrate', 'histogram_quantile(0.50, sum by (installation_id, le, direction) (rate(boohtacord_media_bitrate_kbps_bucket' + scope + '[5m])))')]),
        'voice-roster': dashboard('voice-roster', 'Installation · Voice roster', [
            ('Roster failures', 'sum by (installation_id) (rate(voice_platform_voice_roster_failures_total' + scope + '[5m]))'),
            ('Roster streams', 'sum by (installation_id) (voice_platform_voice_roster_streams_active' + scope + ')')]),
        'fleet': dashboard('fleet', 'BOOHTACORD · Registered installations', [
            ('Registered installations', 'boohtacord_installation_registered'),
            ('Last seen (zero means never connected)', 'boohtacord_installation_last_seen_seconds'),
            ('Enabled (zero means revoked)', 'boohtacord_installation_enabled'),
            ('Explicitly disabled export', 'boohtacord_installation_export_disabled')]),
    }
    trace = dashboard('traces', 'Installation · User and flow traces', [])
    variables = trace['templating']['list']
    for name, field in [('user', 'user.id'), ('session', 'session.id'), ('visit', 'app.visit.id'), ('flow', 'app.flow.id'), ('media', 'app.media.session.id')]:
        query = '{ resource.boohtacord.installation.id = "$installation"'
        for previous in variables[1:]:
            query += ' && span.' + previous['field'] + ' =~ "${' + previous['name'] + ':regex}"'
        query += ' }'
        variables.append({'name': name, 'label': name.title(), 'type': 'query', 'datasource': TEMPO,
                          'field': field, 'query': {'type': 1, 'label': field, 'query': query},
                          'refresh': 2, 'includeAll': True, 'allValue': '.*', 'multi': False})
    query = '{ resource.boohtacord.installation.id = "$installation" && span.user.id =~ "${user:regex}" && span.session.id =~ "${session:regex}" && span.app.visit.id =~ "${visit:regex}" && span.app.flow.id =~ "${flow:regex}" }'
    trace['panels'] = [{'id': 1, 'title': 'Correlated traces (pseudonyms only)', 'type': 'table', 'datasource': TEMPO,
                        'gridPos': {'x': 0, 'y': 0, 'w': 24, 'h': 14},
                        'targets': [{'refId': 'A', 'queryType': 'traceql', 'query': query, 'limit': 100}],
                        'description': 'Datasource is provisioned per registered tenant through the private owner read gateway. Installation selection is not an ACL.'}]
    docs['traces'] = trace
    return docs


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for name, document in build().items():
        (OUT / (name + '.json')).write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
