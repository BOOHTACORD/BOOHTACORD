"""Synthetic dashboard semantics after Collector → actual Tempo storage.

TRACE_DASHBOARD_RUNTIME=1 enables this only on the existing loopback QA stack.
These fixtures prove queries/graph matching, not authentication, client behavior,
production publication, physical media, or load. The relay has its own runtime
suite; no trusted server identity is inferred from a synthetic OTLP POST here.
"""
import json
import os
import pathlib
import time
import unittest
import urllib.parse
import urllib.request
import uuid

from tools.qa.trace_queries.check_trace_queries import panels, private_endpoint, render_query


ROOT = pathlib.Path(__file__).resolve().parents[3]


def loopback(value):
    endpoint = private_endpoint(value)
    if urllib.parse.urlsplit(endpoint).hostname not in ('127.0.0.1', 'localhost', '::1'):
        raise ValueError('synthetic writes require the isolated loopback QA stack')
    return endpoint


@unittest.skipUnless(os.environ.get('TRACE_DASHBOARD_RUNTIME') == '1', 'isolated Tempo runtime opt-in required')
class RuntimeDashboardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.collector = loopback(os.environ.get('TRACE_QA_COLLECTOR_URL', 'http://127.0.0.1:14318'))
        cls.tempo = loopback(os.environ.get('TRACE_QA_TEMPO_URL', 'http://127.0.0.1:13200'))
        cls.dashboard = json.loads((ROOT/'docker/observability/dashboards/traces.json').read_text())
        cls.panels = {p['id']: p for p in panels(cls.dashboard['panels'])}
        cls.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        cls.user = 'qa513-'+uuid.uuid4().hex
        cls.session = uuid.uuid4().hex
        cls.visit = uuid.uuid4().hex

    def setUp(self):
        # Tempo rejects timestamps outside its ingestion slack. A long suite
        # must not reuse one old setup timestamp for later independent cases.
        self.at = time.time_ns()-5_000_000_000

    def values(self, **overrides):
        values = {v['name']: '$__all' for v in self.dashboard['templating']['list']}
        values.update(user=self.user, session=self.session, visit=self.visit)
        values.update(overrides)
        return values

    def attrs(self, **extra):
        values = {'app.schema.version': 1, 'user.id': self.user, 'session.id': self.session,
                  'app.visit.id': self.visit, 'app.flow.id': uuid.uuid4().hex,
                  'app.flow.name': 'message.send', 'app.flow.attempt': 1,
                  'app.flow.stage': 'intent', 'app.flow.outcome': 'unknown',
                  'app.provenance': 'client_observed', 'app.client.version': '1.0.47+82'}
        values.update(extra)
        return values

    def span(self, trace_id, span_id, attrs, parent=None, error=False, duration=1_000_000):
        result = {'traceId': trace_id, 'spanId': span_id, 'name': attrs.get('name', 'message.send'),
                  'kind': 1, 'startTimeUnixNano': str(self.at), 'endTimeUnixNano': str(self.at+duration),
                  'attributes': [self.attribute(k,v) for k,v in attrs.items() if k != 'name'],
                  'status': {'code': 2 if error else 0}}
        if parent:
            result['parentSpanId'] = parent
        return result

    @staticmethod
    def attribute(key, value):
        kind = 'boolValue' if isinstance(value, bool) else 'intValue' if isinstance(value, int) else 'doubleValue' if isinstance(value, float) else 'stringValue'
        return {'key': key, 'value': {kind: str(value) if kind == 'intValue' else value}}

    def send(self, spans, service='boohtacord-web', platform='web'):
        attrs = {'service.name': service}
        if platform:
            attrs['client.platform'] = platform
        body = {'resourceSpans': [{'resource': {'attributes': [self.attribute(k,v) for k,v in attrs.items()]},
                  'scopeSpans': [{'scope': {'name': 'boohtacord/qa513-dashboard'}, 'spans': spans}]}]}
        request = urllib.request.Request(self.collector+'/v1/traces', json.dumps(body).encode(),
                                         {'Content-Type': 'application/json'}, method='POST')
        with self.opener.open(request, timeout=5) as response:
            self.assertEqual(response.status, 200)

    def search(self, panel_id, values):
        query = render_query(self.panels[panel_id]['targets'][0]['query'], values)
        params = urllib.parse.urlencode({'q': query, 'start': int(time.time())-900,
                                         'end': int(time.time())+1, 'limit': 500, 'spss': 50})
        with self.opener.open(self.tempo+'/api/search?'+params, timeout=10) as response:
            return {r['traceID'].lower().zfill(32) for r in json.load(response).get('traces', [])}

    def stored_records(self, trace_id):
        request = urllib.request.Request(self.tempo+'/api/traces/'+trace_id,
                                         headers={'Accept': 'application/json'})
        with self.opener.open(request, timeout=10) as response:
            body = json.load(response)
        found = set()
        def visit(node):
            if isinstance(node, dict):
                if node.get('key') == 'app.flow.record':
                    found.add(node.get('value', {}).get('stringValue'))
                for value in node.values():
                    visit(value)
            elif isinstance(node, list):
                for value in node:
                    visit(value)
        visit(body)
        return found

    def eventually(self, assertion, timeout=35):
        deadline = time.monotonic()+timeout
        while True:
            try:
                assertion()
                return
            except AssertionError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(.25)

    def test_01_terminal_parent_excludes_complete_start_but_not_missing_parent(self):
        flow = uuid.uuid4().hex
        complete, incomplete = uuid.uuid4().hex, uuid.uuid4().hex
        root, child = uuid.uuid4().hex[:16], uuid.uuid4().hex[:16]
        terminal = self.attrs(**{'app.flow.id': flow, 'app.flow.record': 'terminal', 'app.flow.outcome': 'success'})
        start = dict(terminal, **{'app.flow.record': 'start', 'app.flow.outcome': 'unknown'})
        self.send([self.span(complete, root, terminal, duration=1_000_000_000), self.span(complete, child, start, parent=root),
                   self.span(incomplete, uuid.uuid4().hex[:16], start, parent=uuid.uuid4().hex[:16])])
        def check():
            result = self.search(42, self.values(flow=flow))
            self.assertTrue(incomplete in result, 'unmatched start must remain an incomplete observation')
            self.assertFalse(complete in result, 'stored terminal parent must exclude the complete start')
        self.eventually(check)
        self.assertFalse(self.search(42, self.values(flow=flow,outcome='failed')), 'missing terminal is not failed')

    def test_02_late_terminal_changes_quality_without_fabricating_failure(self):
        trace_id, root, flow = uuid.uuid4().hex, uuid.uuid4().hex[:16], uuid.uuid4().hex
        start = self.attrs(**{'app.flow.id': flow, 'app.flow.record': 'start'})
        self.send([self.span(trace_id, uuid.uuid4().hex[:16], start, parent=root)])
        self.eventually(lambda: self.assertTrue(trace_id in self.search(42, self.values(flow=flow))))
        terminal = dict(start, **{'app.flow.record': 'terminal', 'app.flow.outcome': 'success'})
        self.send([self.span(trace_id, root, terminal, duration=1_000_000_000)])
        def check():
            self.assertTrue(trace_id in self.search(41, self.values(flow=flow)))
            self.assertTrue({'start', 'terminal'} <= self.stored_records(trace_id))
        self.eventually(check)
        # Search evaluates partial storage blocks, while trace-ID lookup merges
        # them. A late root can leave a start candidate in another block. The
        # dashboard must say this, rather than report a missing terminal/failure.
        self.assertIn('searched storage block/window', self.panels[42]['description'])
        self.assertIn('not proof', self.panels[42]['description'])
        self.assertFalse(trace_id in self.search(43, self.values(flow=flow)))

    def test_03_short_single_span_and_distinct_outcomes_survive(self):
        flow = uuid.uuid4().hex
        expected = {}
        records = []
        for outcome in ('success','failed','timeout','rejected','cancelled','superseded'):
            trace_id = uuid.uuid4().hex
            expected[outcome] = trace_id
            attrs = self.attrs(**{'app.flow.id':flow,'app.flow.record':'terminal','app.flow.outcome':outcome})
            records.append(self.span(trace_id,uuid.uuid4().hex[:16],attrs,error=outcome in ('failed','timeout'),duration=1))
        self.send(records)
        def check():
            self.assertEqual(len(self.search(41,self.values(flow=flow))),6)
            self.assertEqual(len(self.search(43,self.values(flow=flow))),2)
            self.assertEqual(len(self.search(50,self.values(flow=flow))),3)
        self.eventually(check)

    def test_04_visits_and_accounts_do_not_mix(self):
        flow = uuid.uuid4().hex
        this, other_visit, other_user = [uuid.uuid4().hex for _ in range(3)]
        attrs = self.attrs(**{'app.flow.id':flow,'app.flow.record':'terminal','app.flow.outcome':'success'})
        self.send([self.span(this,uuid.uuid4().hex[:16],attrs),
                   self.span(other_visit,uuid.uuid4().hex[:16],dict(attrs,**{'app.visit.id':uuid.uuid4().hex})),
                   self.span(other_user,uuid.uuid4().hex[:16],dict(attrs,**{'user.id':'qa513-other-'+uuid.uuid4().hex}))])
        def check():
            result = self.search(41,self.values(flow=flow))
            self.assertTrue(this in result)
            self.assertFalse(other_visit in result)
            self.assertFalse(other_user in result)
        self.eventually(check)

    def test_05_api_observed_media_keeps_windows_platform_and_session(self):
        trace_id, media = uuid.uuid4().hex,uuid.uuid4().hex
        attrs = {'name':'media.sample','user.id':self.user,'session.id':self.session,
                 'app.media.session.id':media,'client.platform':'windows','media.platform':'windows_native',
                 'media.direction':'receiver','media.state':'playing','media.bitrate_kbps':321.5,
                 'media.rtt_ms':24.0,'media.measurement_source':'client_webrtc'}
        self.send([self.span(trace_id,uuid.uuid4().hex[:16],attrs)],service='boohtacord-api',platform=None)
        values = self.values(visit='$__all',flow='$__all',media=media,platform='windows',producer='boohtacord-api')
        self.eventually(lambda: self.assertTrue(trace_id in self.search(34,values)))
        self.assertFalse(self.search(34,dict(values,platform='web')))
        self.assertFalse(self.search(34,dict(values,media=uuid.uuid4().hex)))

    def test_06_preauth_errors_need_no_fake_identity(self):
        trace_id = uuid.uuid4().hex
        self.send([self.span(trace_id,uuid.uuid4().hex[:16],{'name':'auth.login','operation.failure_stage':'authentication'},error=True)],service='boohtacord-api',platform=None)
        self.eventually(lambda: self.assertTrue(trace_id in self.search(51,self.values())))

    def test_09_preauth_http_denials_are_visible_without_error_status(self):
        trace_id = uuid.uuid4().hex
        self.send([self.span(trace_id,uuid.uuid4().hex[:16],
                  {'name':'POST /api/v1/auth/login','http.route':'POST /api/v1/auth/login',
                   'http.response.status_code':401,'operation.failure_stage':'authentication'})],
                  service='boohtacord-api',platform=None)
        self.eventually(lambda: self.assertTrue(trace_id in self.search(51,self.values())))

    def test_07_identityless_workers_only_appear_under_all_identity(self):
        trace_id, flow = uuid.uuid4().hex,uuid.uuid4().hex
        self.send([self.span(trace_id,uuid.uuid4().hex[:16],{'name':'voice.sfu_revocation.attempt','app.flow.id':flow,'app.worker.attempt':1,'app.worker.result':'sfu_api_ack'})],service='boohtacord-api',platform=None)
        all_values = self.values(user='$__all',session='$__all',visit='$__all',flow=flow)
        self.eventually(lambda: self.assertTrue(trace_id in self.search(44,all_values)))
        self.assertFalse(self.search(44,self.values(flow=flow)))

    def test_08_legacy_client_needs_no_new_platform_or_version_attribute(self):
        trace_id, flow = uuid.uuid4().hex,uuid.uuid4().hex
        attrs = self.attrs(**{'app.flow.id':flow,'app.flow.record':'terminal','app.flow.outcome':'success'})
        del attrs['app.client.version']
        self.send([self.span(trace_id,uuid.uuid4().hex[:16],attrs)],platform=None)
        self.eventually(lambda: self.assertTrue(trace_id in self.search(41,self.values(flow=flow,platform='web'))))
        self.assertFalse(self.search(41,self.values(flow=flow,client_version='1.0.47+82')))


if __name__ == '__main__':
    unittest.main()
