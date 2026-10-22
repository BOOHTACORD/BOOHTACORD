"""Query validation covers collapsed panels, escaping and honest bounded reports."""
import unittest

from tools.qa.trace_queries.check_trace_queries import private_endpoint, render_query, targets


class QueryChecksTest(unittest.TestCase):
    def test_nested_panels_include_trace_and_promql_targets(self):
        dashboard = {'panels': [{'id': 1, 'panels': [
            {'id': 2, 'targets': [{'queryType': 'traceql', 'query': '{}'}]},
            {'id': 3, 'targets': [{'expr': 'up'}]},
        ]}]}
        self.assertEqual([(p['id'], kind) for p, _, kind in targets(dashboard)], [(2, 'traceql'), (3, 'promql')])

    def test_regex_values_are_literal_and_traceql_string_escaped(self):
        self.assertEqual(render_query('{ span.user.id =~ "${user:regex}" }', {'user': ['a+b', 'a.b']}),
                         '{ span.user.id =~ "(a\\\\+b|a\\\\.b)" }')
        self.assertEqual(render_query('"${user:regex}"', {'user': 'a"b'}), '"a\\"b"')
        self.assertEqual(render_query('"${user:regex}"', {'user': '$__all'}), '".*"')

    def test_grafana_regex_format_is_supported_in_traceql_raw_literals(self):
        self.assertEqual(render_query('`$' + '{operation:regex}`', {'operation': 'screen.view'}),
                         '`screen\\.view`')
        self.assertEqual(render_query('`$' + '{client_version:regex}`', {'client_version': '0.0.0+513'}),
                         '`0\\.0\\.0\\+513`')
        self.assertEqual(render_query('`boohtacord-${platform:regex}`', {'platform': ['web', 'windows']}),
                         '`boohtacord-(web|windows)`')
        with self.assertRaises(ValueError):
            render_query('`$' + '{user:regex}`', {'user': 'unsafe`delimiter'})

    def test_unknown_or_unexpanded_variable_is_not_silently_accepted(self):
        with self.assertRaises(ValueError):
            render_query('${unknown:regex}', {})
        with self.assertRaises(ValueError):
            render_query('${user:raw}', {'user': 'one'})

    def test_only_private_qa_endpoints_are_used_without_credentials(self):
        self.assertEqual(private_endpoint('http://127.0.0.1:13200/'), 'http://127.0.0.1:13200')
        for url in ('https://example.com', 'http://1.1.1.1', 'http://user:secret@127.0.0.1',
                    'file:///tmp/example', 'http://127.0.0.1?q=secret'):
            with self.assertRaises(ValueError):
                private_endpoint(url)


if __name__ == '__main__':
    unittest.main()
