"""The action history must not confuse sampling, scope, or service traffic with outcomes."""
import json
import unittest

from tools.verify.trace_dashboard.fixture import DashboardFixture


class ActionHistoryTest(DashboardFixture):
    def test_grafana_regex_filters_use_traceql_raw_literals(self):
        # Grafana :regex emits \., which is invalid in TraceQL JSON literals.
        import re
        from tools.qa.trace_queries.check_trace_queries import panels
        for panel in panels(self.dashboard['panels']):
            for target in panel.get('targets', []):
                if target.get('queryType') == 'traceql':
                    self.assertFalse(re.search(r'"[^"`\n]*\$\{[a-z_]+:regex\}[^"`\n]*"', target['query']))
                    self.assertNotIn('resource.service.name =~ `boohtacord-${platform:regex}`', target['query'])

    def test_only_actions_and_quality_are_on_the_first_screen(self):
        visible = {p['id'] for p in self.dashboard['panels'] if p['type'] != 'row'}
        self.assertEqual(visible, {40, 41, 42, 43, 50, 51})
        for panel_id in (29, 52, 53, 54):
            self.assertTrue(self.panels[panel_id]['collapsed'])
        self.assertIn('500', self.panels[40]['options']['content'])
        self.assertIn('sampling', self.panels[40]['options']['content'])

    def test_stable_identity_does_not_require_uuid_display_labels(self):
        variables = {v['name']: v for v in self.dashboard['templating']['list']}
        self.assertEqual(variables['user']['query']['label'], 'user.id')
        self.assertEqual(variables['user'].get('regex', ''), '')
        # Tempo 13 ignores an arbitrary query.query property on LabelValues.
        # Supported scoped table links provide actual dependent selection.
        for variable in variables.values():
            if isinstance(variable.get('query'), dict):
                self.assertNotIn('query', variable['query'])
        self.assertIn('${user:regex}', self.panels[60]['targets'][0]['query'])
        self.assertIn('${session:regex}', self.panels[61]['targets'][0]['query'])
        session_link = json.dumps(self.panels[60]['fieldConfig'])
        visit_link = json.dumps(self.panels[61]['fieldConfig'])
        self.assertIn('var-visit=$__all', session_link)
        self.assertIn('var-flow=$__all', visit_link)
        self.assertIn('var-media=$__all', visit_link)
        self.assertIn('var-visit=$__all', json.dumps(self.dashboard['links']))

    def test_platform_is_client_origin_and_producer_is_independent(self):
        variables = {v['name']: v for v in self.dashboard['templating']['list']}
        self.assertEqual(variables['platform']['type'], 'custom')
        self.assertEqual(variables['producer']['query']['label'], 'service.name')
        for panel_id in (41, 42, 43, 45, 48, 49):
            query = self.panels[panel_id]['targets'][0]['query']
            # client.platform has the same bounded enum in the validated
            # client resource or API media span; unscoped lookup covers both.
            self.assertIn('.client.platform', query)
            self.assertIn('${producer:regex}', query)
        self.assertIn('span.media.platform', self.panels[34]['targets'][0]['query'])
        self.assertIn('${platform:regex}', self.panels[34]['targets'][0]['query'])

    def test_incomplete_is_unmatched_start_not_a_missing_sibling_or_failed_attempt(self):
        panel = self.panels[42]
        query = panel['targets'][0]['query']
        parent, start = query.split('!>')
        self.assertIn('.app.flow.record = "terminal"', parent)
        self.assertIn('.app.flow.record = "start"', start)
        for variable in ('user', 'session', 'visit', 'flow', 'media', 'platform', 'client_version', 'producer', 'operation'):
            self.assertIn('${' + variable + ':regex}', start)
        # The parent need not match the current outcome/version selection: its
        # actual existence is enough to make "missing terminal" a false claim.
        self.assertNotIn('${outcome:regex}', parent)
        self.assertNotIn('span.app.flow.outcome =~', parent)
        self.assertIn('`${outcome:regex}`', start)
        self.assertIn('parent', panel['description'])
        self.assertIn('not proof', panel['description'])

    def test_errors_are_separate_from_denials_and_user_cancellations(self):
        errors = self.panels[43]['targets'][0]['query']
        choices = self.panels[50]['targets'][0]['query']
        self.assertIn('"failed|timeout"', errors)
        self.assertIn('"rejected|cancelled|superseded"', choices)
        self.assertNotIn('duration >', self.panels[41]['targets'][0]['query'])
        self.assertIn('status = error', self.panels[51]['targets'][0]['query'])
        self.assertIn('.http.response.status_code >= 400', self.panels[51]['targets'][0]['query'])
        self.assertIn('denials', self.panels[51]['description'])
        self.assertIn('no fabricated user identity', self.panels[51]['description'])
        self.assertIn('GLOBAL', self.panels[51]['title'])

    def test_worker_legacy_rows_cannot_leak_through_a_selected_identity(self):
        panel = self.panels[44]
        query = panel['targets'][0]['query']
        for variable in ('user', 'session', 'visit', 'flow'):
            self.assertIn('${' + variable + ':regex}', query)
        self.assertIn('`${user:regex}` = ".*"', query)
        self.assertIn('GLOBAL', panel['description'])
        self.assertIn('cross-trace', panel['description'])

    def test_media_samples_are_history_not_merged_unrelated_last_values(self):
        for panel_id in (33, 34, 45):
            panel = self.panels[panel_id]
            self.assertFalse(any(t['id'] == 'groupBy' for t in panel.get('transformations', [])))
            query = panel['targets'][0]['query']
            self.assertIn('.app.media.session.id', query)
            self.assertIn('${media:regex}', query)
        self.assertIn('uncorrelated', self.panels[33]['description'])
        self.assertIn('sample age', self.panels[45]['description'])
        self.assertIn('kbps', self.panels[34]['description'])

    def test_global_relay_receipt_does_not_masquerade_as_tempo_storage(self):
        panel = self.panels[47]
        expression = panel['targets'][0]['expr']
        self.assertNotIn('max(', expression)
        self.assertIn('not stored', panel['description'])
        self.assertIn('GLOBAL', panel['title'])
        self.assertIn('instance', panel['targets'][0]['legendFormat'])
        for panel_id in (46, 47, 55):
            self.assertIn('GLOBAL', self.panels[panel_id]['title'])
            for target in self.panels[panel_id]['targets']:
                self.assertNotIn('or vector(0)', target.get('expr', ''))

    def test_action_links_keep_org_time_and_clear_descendant_filters(self):
        for panel_id in (41, 42, 43, 48, 50):
            panel = self.panels[panel_id]
            links = json.dumps(panel['fieldConfig']['overrides'])
            self.assertIn('orgId=1', links)
            self.assertIn('${__url_time_range}', links)
            self.assertIn('var-flow=${__value.raw}', links)
            self.assertIn('var-media=$__all', links)
            self.assertIn('traceID', links)

    def test_media_selection_does_not_pass_all_and_selected_id_together(self):
        for panel_id in (33, 34, 45, 59):
            override = next(o for o in self.panels[panel_id]['fieldConfig']['overrides']
                            if o['matcher']['options'] == 'app.media.session.id')
            link = next(p for p in override['properties'] if p['id'] == 'links')['value'][0]['url']
            self.assertEqual(link.count('var-media='), 1)
            self.assertIn('var-media=${__value.raw}', link)


if __name__ == '__main__':
    unittest.main()
